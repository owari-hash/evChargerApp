import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'models/app_update.dart';
import 'models/charging_session.dart';
import 'models/wallet.dart';
import 'screens/account_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/mongolia_map_screen.dart';

import 'screens/sessions_screen.dart';
import 'screens/trips_stations_screen.dart';
import 'services/announcement_service.dart';
import 'services/announcement_watcher_service.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/sessions_service.dart';
import 'services/stations_service.dart';
import 'services/notifications_store.dart';
import 'services/session_watcher_service.dart';
import 'services/wallet_watcher_service.dart';
import 'utils/money.dart';
import 'theme/app_theme.dart';
import 'utils/app_info.dart';
import 'utils/app_strings.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/announcement_dialog.dart';
import 'widgets/assistant_sheet.dart';
import 'widgets/draggable_assistant_button.dart';
import 'widgets/charge_notifications.dart';
import 'widgets/guided_step.dart';
import 'widgets/notifications_sheet.dart';
import 'widgets/app_toast.dart';

void main() async {
  // The bundle version is read over a platform channel, so the binding has to
  // exist first. It is awaited rather than fired off, because the sign-in
  // footer renders the version on the very first frame.
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  runApp(const EvChargerApp());
}

class EvChargerApp extends StatelessWidget {
  const EvChargerApp({super.key, this.authService, this.startupPrompts});

  /// Injectable so tests can run the app against a stubbed driver API.
  final AuthService? authService;

  /// Replaces the cold-start update and announcement prompts. Tests only.
  final Future<void> Function(BuildContext context)? startupPrompts;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (BuildContext context, AppLanguage _, Widget? _) {
            return MaterialApp(
              title: 'Eplug',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: MainAppFrame(
                authService: authService,
                startupPrompts: startupPrompts,
              ),
            );
          },
        );
      },
    );
  }
}

class MainAppFrame extends StatefulWidget {
  const MainAppFrame({super.key, this.authService, this.startupPrompts});

  final AuthService? authService;

  /// Replaces the cold-start update and announcement prompts. Tests only.
  final Future<void> Function(BuildContext context)? startupPrompts;

  @override
  State<MainAppFrame> createState() => _MainAppFrameState();
}

/// A pop-up held back while the first-run guide is on screen.
class _QueuedBanner {
  const _QueuedBanner({required this.show, this.transactionId});

  final VoidCallback show;

  /// Set for a charge's pop-up, so a finish queued behind its own start
  /// replaces it instead of the driver getting both, stale, afterwards.
  final int? transactionId;
}

class _MainAppFrameState extends State<MainAppFrame>
    with WidgetsBindingObserver {
  AuthService get _auth => widget.authService ?? AuthService.instance;

  /// True until a session saved on a previous launch has been checked, so the
  /// app does not flash the sign-in screen at a driver who is already signed in.
  bool _bootstrapping = true;

  /// Guards the update prompt to one attempt per process.
  bool _updateChecked = false;
  /// 0: Home, 1: Map, 2: Quick Controls, 3: Stations, 4: Account.
  ///
  /// The map is where the app opens, for a guest and a signed-in driver alike:
  /// finding a charger is the reason the app gets opened, and it is the part
  /// that needs no account.
  int _activeTabIndex = _mapTab;

  static const int _homeTab = 0;
  static const int _mapTab = 1;
  static const int _accountTab = 4;

  /// The server's id for this app's walkthrough in `pendingGuides`.
  static const String _appGuide = 'app';

  /// Four steps on the dashboard, the last on the bottom bar.
  static const int _navGuideStep = 4;

  final AppGuideController _guide = AppGuideController(totalSteps: 5);

  /// Whether a driver was signed in at the last auth change, so the guide is
  /// considered on a sign-in and not on every profile update.
  bool _wasSignedIn = false;

  /// False until the cold-start update and announcement prompts are done, so
  /// a sign-in cannot start the guide underneath one of them.
  bool _startupPromptsDone = false;

  bool get _isLoggedIn => _auth.isSignedIn;

  /// Pop-ups waiting for the guide to close.
  final List<_QueuedBanner> _queuedBanners = <_QueuedBanner>[];

  /// When a charge's end was last put in front of the driver — a «Цэнэглэлт
  /// дууслаа» pop-up or the dashboard's receipt. The wallet debit for that
  /// same charge lands a moment later and says nothing new, so it only goes
  /// in the bell.
  DateTime? _chargeEndShownAt;

  /// When the wallet watcher last popped up a charge debit, so a «Цэнэглэлт
  /// дууслаа» right behind it replaces it instead of stacking.
  DateTime? _debitShownAt;

  static const Duration _sameChargeWindow = Duration(minutes: 2);

  /// The newest unseen Мэдээ, waiting for a moment it can be shown in.
  Announcement? _pendingAnnouncement;
  bool _announcementShowing = false;
  Timer? _announcementRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasSignedIn = _isLoggedIn;
    _auth.currentUser.addListener(_onAuthChanged);
    _guide.addListener(_onGuideChanged);
    _guide.onFinished = _onGuideFinished;
    GuidedStep.onTriggerGuide = _replayGuide;
    StationsService.instance.targetStation.addListener(_onTargetStationChanged);
    _restoreSession();
    if (_isLoggedIn) _startWatchers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.currentUser.removeListener(_onAuthChanged);
    _guide.removeListener(_onGuideChanged);
    StationsService.instance.targetStation.removeListener(_onTargetStationChanged);
    _guide.dispose();
    if (GuidedStep.onTriggerGuide == _replayGuide) {
      GuidedStep.onTriggerGuide = null;
    }
    WalletWatcherService.instance.stop();
    SessionWatcherService.instance.stop();
    AnnouncementWatcherService.instance.stop();
    _announcementRetry?.cancel();
    super.dispose();
  }

  void _onTargetStationChanged() {
    if (StationsService.instance.targetStation.value != null && mounted) {
      setState(() {
        _activeTabIndex = _mapTab;
      });
    }
  }

  /// Polling only while the app is in front; coming back checks straight
  /// away, so a charge that finished in the meantime is reported then.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isLoggedIn) _startWatchers();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        WalletWatcherService.instance.stop();
        SessionWatcherService.instance.stop();
        AnnouncementWatcherService.instance.stop();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// The bottom-bar step lives here, the rest on the dashboard.
  void _onGuideChanged() {
    if (mounted) setState(() {});
    if (!_guideOnScreen) _flushBanners();
  }

  /// Requested counts too: the dashboard starts it a moment later, and a
  /// pop-up raised in between would sit on top of its first step.
  bool get _guideOnScreen => _guide.isActive || _guide.requested;

  /// Shows [show] now, or once the guide has closed — a SnackBar over the
  /// guide covers the step it is pointing at.
  void _presentBanner(VoidCallback show, {int? transactionId}) {
    if (!_guideOnScreen) {
      show();
      return;
    }
    if (transactionId != null) {
      _queuedBanners.removeWhere(
        (_QueuedBanner b) => b.transactionId == transactionId,
      );
    }
    _queuedBanners.add(_QueuedBanner(show: show, transactionId: transactionId));
  }

  void _flushBanners() {
    if (_queuedBanners.isEmpty || !mounted) return;
    final List<_QueuedBanner> queued = List<_QueuedBanner>.of(_queuedBanners);
    _queuedBanners.clear();
    // ScaffoldMessenger shows them one after another.
    for (final _QueuedBanner banner in queued) {
      banner.show();
    }
  }

  /// Shows the walkthrough to a driver the server still lists it for — a new
  /// account. Runs after a launch with a saved session and after a sign-in or
  /// sign-up; a guest never gets here.
  void _maybeStartGuide() {
    if (!mounted || !_isLoggedIn) return;
    if (_auth.shouldShowGuide(_appGuide)) {
      _startGuide(replay: false);
    } else {
      // A "done" that failed offline earlier gets another go.
      unawaited(_auth.retryGuideDone(_appGuide));
    }
  }

  /// From «Аппын заавар үзэх»: ignores the server flag and never writes it.
  void _replayGuide() {
    if (!mounted || !_isLoggedIn) return;
    _startGuide(replay: true);
  }

  /// The steps point at the dashboard, so go there first. The dashboard
  /// starts the guide itself once its first load is in and nothing modal is
  /// on top of it.
  void _startGuide({required bool replay}) {
    setState(() => _activeTabIndex = _homeTab);
    _guide.request(replay: replay);
  }

  /// Ticked «Дахиж харахгүй», or went through to «Ойлголоо»: the server is
  /// told, so it never shows again. A plain skip only hides it until the next
  /// launch or sign-in.
  void _onGuideFinished({required bool markDone}) {
    if (markDone) {
      unawaited(_auth.markGuideDone(_appGuide));
    } else {
      _auth.dismissGuideForSession(_appGuide);
    }
  }

  /// Wallet and charge watchers, and the bell's history, for whoever is
  /// signed in now. Safe to call on every auth change and every resume.
  void _startWatchers() {
    final String? userId = _auth.currentUser.value?.id;
    if (userId == null) return;
    unawaited(NotificationsStore.instance.setUser(userId));
    WalletWatcherService.instance.start(
      userId: userId,
      onNewEntry: _onWalletEntry,
    );
    SessionWatcherService.instance.start(
      userId: userId,
      onEvent: _onSessionEvent,
    );
    AnnouncementWatcherService.instance.start(
      userId: userId,
      accountCreatedAt: _auth.currentUser.value?.createdAt,
      onNew: _onAnnouncements,
    );
  }

  /// Signed out: nothing of this driver's may show for the next one.
  void _stopWatchersForSignOut() {
    WalletWatcherService.instance.stop();
    SessionWatcherService.instance.signOut();
    AnnouncementWatcherService.instance.signOut();
    unawaited(NotificationsStore.instance.setUser(null));
    _queuedBanners.clear();
    _pendingAnnouncement = null;
    _announcementRetry?.cancel();
    _chargeEndShownAt = null;
    _debitShownAt = null;
  }

  bool _within(DateTime? at, Duration window) =>
      at != null && DateTime.now().difference(at) <= window;

  void _onWalletEntry(WalletEntry entry) {
    final String label = _walletEntryLabel(entry);
    final String amount =
        '${entry.isCredit ? '+' : ''}${formatMntLeading(entry.amount.toDouble())}';
    unawaited(
      NotificationsStore.instance.add(
        kind: NotificationKind.wallet,
        title: label,
        body: amount,
      ),
    );
    if (!mounted) return;
    final bool isChargeDebit = entry.type == WalletEntryType.charge;
    // The charge's own pop-up or receipt already gave the cost.
    if (isChargeDebit && _within(_chargeEndShownAt, _sameChargeWindow)) return;
    _presentBanner(() {
      if (!mounted) return;
      if (isChargeDebit) _debitShownAt = DateTime.now();
      AppToast.show(
        context,
        amount,
        title: label,
        kind: entry.isCredit ? ToastKind.success : ToastKind.info,
      );
    });
  }

  void _onSessionEvent(SessionEvent event) {
    final ({String title, String body}) text = chargeNotificationText(event);
    unawaited(
      NotificationsStore.instance.add(
        kind: chargeNotificationKind(event),
        title: text.title,
        body: text.body,
        transactionId: event.session.transactionId,
      ),
    );
    final bool stopped = event.type == SessionEventType.stopped;
    if (stopped) _chargeEndShownAt = DateTime.now();
    // The QR flow's own snackbar or the dashboard's receipt already said so.
    if (event.confirmedInApp || !mounted) return;
    _presentBanner(() {
      if (!mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      if (stopped && _within(_debitShownAt, _sameChargeWindow)) {
        // Replaces the debit pop-up for the same charge: this one says more.
        messenger.hideCurrentSnackBar();
        _debitShownAt = null;
      }
      messenger.showSnackBar(
        chargeSnackBar(
          context,
          event,
          onView: () => _openCharge(chargeNotificationKind(event)),
        ),
      );
    }, transactionId: event.session.transactionId);
  }

  /// New Мэдээ, newest first. All of them go in the bell; the newest is put
  /// in front of the driver — after the cold-start prompts, never under the
  /// guide, and never over a sheet, dialog or page they are busy in.
  void _onAnnouncements(List<Announcement> fresh) {
    for (final Announcement a in fresh.reversed) {
      unawaited(
        NotificationsStore.instance.add(
          kind: NotificationKind.announcement,
          title: a.title,
          body: a.body,
          imageUrl: a.imageUrl,
          // Shown with when it was published, not when this phone saw it;
          // the key matches the website's, so it is filed once.
          at: a.createdAt,
          dedupeKey: 'announcement:${a.id}',
        ),
      );
    }
    _pendingAnnouncement = fresh.first;
    if (_startupPromptsDone) {
      _presentBanner(() => unawaited(_showPendingAnnouncement()));
    }
  }

  Future<void> _showPendingAnnouncement() async {
    final Announcement? announcement = _pendingAnnouncement;
    if (announcement == null || !mounted || _announcementShowing) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _announcementRetry?.cancel();
      _announcementRetry = Timer(
        const Duration(seconds: 2),
        () => _presentBanner(() => unawaited(_showPendingAnnouncement())),
      );
      return;
    }
    _pendingAnnouncement = null;
    _announcementShowing = true;
    try {
      await showAnnouncementDialog(
        context,
        title: announcement.title,
        body: announcement.body,
        imageUrl: announcement.imageUrl,
      );
    } finally {
      _announcementShowing = false;
    }
  }

  /// A charge in progress is on the dashboard; a finished one is in the
  /// history, with its receipt. An announcement opens in full.
  void _openNotification(AppNotification item) {
    if (!mounted) return;
    if (item.kind == NotificationKind.announcement) {
      unawaited(
        showAnnouncementDialog(
          context,
          title: item.title,
          body: item.body,
          imageUrl: item.imageUrl,
        ),
      );
      return;
    }
    _openCharge(item.kind);
  }

  void _openCharge(NotificationKind kind) {
    if (!mounted) return;
    if (kind == NotificationKind.chargeStarted) {
      setState(() => _activeTabIndex = _homeTab);
    } else if (kind == NotificationKind.chargeStopped) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SessionsScreen()),
      );
    }
  }

  String _walletEntryLabel(WalletEntry entry) {
    switch (entry.type) {
      case WalletEntryType.topUp:
        return AppStrings.get('wallet_entry_topup');
      case WalletEntryType.charge:
        return AppStrings.get('wallet_entry_charge');
      case WalletEntryType.refund:
        return AppStrings.get('wallet_entry_refund');
      case WalletEntryType.adjustment:
        return AppStrings.get('wallet_entry_adjustment');
      case WalletEntryType.bonus:
        return AppStrings.get('wallet_entry_bonus');
    }
  }

  Future<void> _restoreSession() async {
    await _auth.restoreSession();
    if (mounted) {
      setState(() {
        _bootstrapping = false;
        _activeTabIndex = _mapTab;
      });
      // After the splash, never during it: a dialog raised over the boot screen
      // has no Scaffold to anchor its snackbar, and a forced update shown before
      // the app has drawn looks like a crash.
      //
      // One prompt at a time, each waiting for the last to be dismissed:
      // update, then announcement, then the guide. A forced update is never
      // dismissed, so nothing is stacked on top of it.
      final Future<void> Function(BuildContext)? prompts =
          widget.startupPrompts;
      if (prompts != null) {
        await prompts(context);
      } else {
        await _checkForUpdate();
        if (_isLoggedIn && mounted) {
          await AnnouncementWatcherService.instance.checkNow();
          await _showPendingAnnouncement();
        }
      }
      if (!mounted) return;
      _startupPromptsDone = true;
      _maybeStartGuide();
    }
  }

  /// Cold start only.
  ///
  /// There is deliberately no polling and no re-check when the app returns from
  /// the background. A driver who has the app open is usually in the middle of
  /// something — plugging in, paying, watching a charge — and a modal thrown
  /// over that, a forced one above all, can leave a session running that they
  /// can no longer stop. Being one launch late with an update is cheap; an
  /// interrupted charge is not.
  ///
  /// Failure is silent by design — see AppUpdateService.
  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;

    final AppUpdateInfo? pending = await AppUpdateService.instance
        .pendingPrompt();
    if (pending == null || !mounted) return;

    // Even on a cold start the driver may have left a charge running. Stay out
    // of the way and ask again next launch.
    if (await _hasLiveChargingSession()) return;
    if (!mounted) return;

    await AppUpdateDialog.show(context, pending);
  }

  /// True when a charge is running on this account right now.
  ///
  /// Errs towards "yes": if the answer cannot be established the prompt is
  /// skipped, because wrongly suppressing an update costs one launch while
  /// wrongly covering the stop button can cost a driver money.
  Future<bool> _hasLiveChargingSession() async {
    if (!_auth.isSignedIn) return false;
    try {
      final List<ChargingSession> recent = await SessionsService.instance.list(
        limit: 5,
      );
      return recent.any((ChargingSession session) => session.isActive);
    } catch (_) {
      return true;
    }
  }

  /// Signing in from a gated action swaps the tabs from their guest state to
  /// the real thing, so the frame rebuilds whenever the session changes.
  void _onAuthChanged() {
    if (!mounted) return;
    final bool justSignedIn = _isLoggedIn && !_wasSignedIn;
    _wasSignedIn = _isLoggedIn;
    if (_isLoggedIn) {
      _startWatchers();
    } else {
      _stopWatchersForSignOut();
      _guide.cancel();
    }
    setState(() {
      // Signing in on the account tab lands the driver back on the map rather
      // than leaving them looking at the profile form they just filled in.
      // A sign-in raised over a gated action is left alone: that one resumes
      // whatever the driver was already doing.
      if (_isLoggedIn && _activeTabIndex == _accountTab) {
        _activeTabIndex = _mapTab;
      }
    });
    // A saved-session launch is handled once the startup prompts are done.
    if (justSignedIn && _startupPromptsDone) _maybeStartGuide();
  }

  /// The camera scanner itself. This used to open the stations list in a
  /// sheet, one more tap away from the camera.
  void _openQrScannerModal(BuildContext context) {
    unawaited(showQrScannerSheet(context));
  }

  void _toggleTheme() {
    ThemeController.toggle();
    setState(() {});
  }

  /// Logging out throws away the session, so make the user mean it.
  Future<void> _confirmLogout() async {
    final AppPalette palette = context.palette;

    final bool? shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.get('logout_title')),
          content: Text(AppStrings.get('logout_body')),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: palette.inkMuted),
              child: Text(AppStrings.get('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.get('logout')),
            ),
          ],
        );
      },
    );

    if (shouldLogOut != true) return;

    await _auth.signOut();
    if (mounted) setState(() => _activeTabIndex = _mapTab);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (_bootstrapping) return const _BootSplash();

    // No sign-in wall. Every tab is reachable signed out; the ones that show a
    // driver's own vehicle, money or history say so and offer to sign them in.
    // App Store guideline 5.1.1(v): an app may not require an account to reach
    // features that are not account based, and finding a charger is not.
    final List<Widget> pages = [
      HomeDashboardScreen(
        authService: widget.authService,
        guide: _guide,
        onScanQr: () => _openQrScannerModal(context),
        onFindCharger: () => setState(() => _activeTabIndex = _mapTab),
        onAddVehicle: () => setState(() => _activeTabIndex = _accountTab),
      ),
      MongoliaMapScreen(onOpenQrScanner: () => _openQrScannerModal(context)),
      // Tab 2 is the QR scanner action — it opens a modal, so this
      // placeholder is never shown.
      const SizedBox.shrink(),
      TripsStationsScreen(),
      AccountScreen(authService: widget.authService),
    ];

    return Scaffold(
      backgroundColor: palette.bg,

      // Clean Top Header App Bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: palette.bg,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 20,
            right: 16,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/ev logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Eplug',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Language, then theme, then logout.
              _LanguageAction(onChanged: () => setState(() {})),
              const SizedBox(width: 8),
              _AppBarAction(
                icon: ThemeController.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                tooltip: ThemeController.isDark
                    ? AppStrings.get('light_mode')
                    : AppStrings.get('dark'),
                onPressed: _toggleTheme,
              ),
              if (_isLoggedIn) ...[
                const SizedBox(width: 8),
                _NotificationBellAction(
                  onOpen: () => showNotificationsSheet(
                    context,
                    onOpen: _openNotification,
                  ),
                ),
                const SizedBox(width: 10),
                _AppBarAction(
                  icon: Icons.logout_rounded,
                  tooltip: AppStrings.get('logout'),
                  onPressed: _confirmLogout,
                ),
              ],
            ],
          ),
        ),
      ),

      body: Stack(
        children: <Widget>[
          IndexedStack(index: _activeTabIndex, children: pages),
          // A button the driver can drag aside: as a fixed FAB it covered the
          // map's own controls. Hidden while the guide runs, which points at
          // the very sections it would sit over.
          if (!_guide.isActive)
            Positioned.fill(
              child: DraggableAssistantButton(
                tooltip: AppStrings.get('assistant_label'),
                onPressed: () =>
                    showAssistantSheet(context, page: _currentTabLabel()),
              ),
            ),
        ],
      ),

      // Floating Bottom Navigation Bar (Full rounded with space on all sides)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 8,
            top: 4,
          ),
          child: GuidedStep.of(
            guide: _guide,
            stepIndex: _navGuideStep,
            tag: AppStrings.get('guide_nav_tag'),
            title: AppStrings.get('guide_nav_title'),
            description: AppStrings.get('guide_nav_body'),
            icon: Icons.map_rounded,
            tipBelow: false,
            borderRadius: 36,
            child: _buildBottomNavBar(palette),
          ),
        ),
      ),
    );
  }

  /// The floating pill of five tabs, as frosted glass so the screen's soft
  /// background light shows through — the same look as the cards above it.
  Widget _buildBottomNavBar(AppPalette palette) {
    final bool isDark = ThemeController.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF10281C).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? <Color>[
                        const Color(0xFF1C2A38).withValues(alpha: 0.78),
                        const Color(0xFF14202C).withValues(alpha: 0.66),
                      ]
                    : <Color>[
                        Colors.white.withValues(alpha: 0.86),
                        Colors.white.withValues(alpha: 0.70),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomNavItem(
                  0,
                  Icons.home_rounded,
                  AppStrings.get('home'),
                ),
                _buildBottomNavItem(
                  1,
                  Icons.map_rounded,
                  AppStrings.get('map'),
                ),
                _buildBottomNavItem(
                  2,
                  Icons.qr_code_scanner_rounded,
                  'QR',
                ),
                _buildBottomNavItem(
                  3,
                  Icons.ev_station_rounded,
                  AppStrings.get('nav_stations'),
                ),
                _buildBottomNavItem(
                  4,
                  Icons.person_rounded,
                  AppStrings.get('nav_account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The active tab's own label, so the assistant's system prompt can stay
  /// relevant to whatever the driver is actually looking at.
  String _currentTabLabel() {
    const keys = ['home', 'map', 'control', 'nav_stations', 'nav_account'];
    final key = keys[_activeTabIndex.clamp(0, keys.length - 1)];
    return AppStrings.get(key);
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isSelected = _activeTabIndex == index;
    final AppPalette palette = context.palette;

    // Equal flex for every tab: an uneven split (extra width for whichever
    // tab is selected) shifted the whole bar's visual weight left or right
    // depending on which end was active, so it never looked centered.
    return Expanded(
      // Keyed so tests can address a tab without matching an icon that also
      // appears inside the tab's own content.
      key: ValueKey<String>('nav-tab-$index'),
      child: GestureDetector(
        onTap: () {
          if (index == 2) {
            _openQrScannerModal(context);
          } else {
            setState(() => _activeTabIndex = index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          // The selected tab is the payment switch's glass pill.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: ThemeController.isDark
                        ? <Color>[
                            const Color(0xFF34D399).withValues(alpha: 0.32),
                            const Color(0xFF10B981).withValues(alpha: 0.14),
                          ]
                        : <Color>[Colors.white, const Color(0xFFEFFDF5)],
                  )
                : null,
            border: Border.all(
              color: isSelected
                  ? const Color(
                      0xFF10B981,
                    ).withValues(alpha: ThemeController.isDark ? 0.42 : 0.30)
                  : Colors.transparent,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: ThemeController.isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.30)
                          : Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? palette.accent : palette.inkMuted,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// MN | EN switch for the app bar.
class _LanguageAction extends StatelessWidget {
  const _LanguageAction({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isMn = AppStrings.currentLanguage == AppLanguage.mn;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _segment(context, AppLanguage.mn, isMn),
          _segment(context, AppLanguage.en, !isMn),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, AppLanguage lang, bool active) {
    final AppPalette palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      label: lang.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          LanguageController.set(lang);
          onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? palette.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          // The inactive flag is dimmed rather than greyed out: an emoji
          // carries its own colour, so opacity is the only lever.
          child: Opacity(
            opacity: active ? 1.0 : 0.45,
            child: Text(lang.flag, style: const TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
  }
}

/// Circular action button used in the app bar.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        shape: BoxShape.circle,
        border: Border.all(color: palette.border),
      ),
      child: IconButton(
        icon: Icon(icon, color: palette.ink, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// The bell in the app bar: wallet changes, announcements and charges
/// starting or finishing that the driver has already seen once as a SnackBar
/// or a modal, kept here so they can find them again — same role as the
/// kiosk website's bell.
class _NotificationBellAction extends StatelessWidget {
  const _NotificationBellAction({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return ValueListenableBuilder<int>(
      valueListenable: NotificationsStore.instance.unread,
      builder: (context, unread, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: palette.ink, size: 20),
                onPressed: onOpen,
                tooltip: AppStrings.get('notifications_label'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown for the moment it takes to check for a saved session.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  /// Matches the `backgroundColor` of `LaunchScreen.storyboard`, which is the
  /// cream the Eplug logo is drawn on. Handing over from the native launch
  /// screen to Flutter is meant to be invisible; using the theme palette here
  /// instead made the app blink from one splash to another.
  static const Color launchBackground = Color(0xFFFAF8F4);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: launchBackground,
      child: Center(
        child: Image(
          image: AssetImage('assets/images/launch_badge.png'),
          width: 220,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
