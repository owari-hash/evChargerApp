import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// Which way money moved.
enum WalletFlow { all, income, expense }

/// The wallet history filter as the sheet edits it.
class WalletFilter {
  const WalletFilter({this.presetDays, this.range, this.flow = WalletFlow.all});

  /// 7, 14, 30 or 90 days back from today; null when none is picked.
  final int? presetDays;

  /// A range picked on the calendar; replaces any preset.
  final DateTimeRange? range;
  final WalletFlow flow;

  static const WalletFilter none = WalletFilter();

  bool get hasDate => presetDays != null || range != null;

  /// How many filters are on, for the badge on the filter button.
  int get activeCount => (hasDate ? 1 : 0) + (flow != WalletFlow.all ? 1 : 0);

  /// Whether [at] falls in the picked dates (always true with no date set).
  /// A preset counts today as one of its days.
  bool includesDate(DateTime? at) {
    if (!hasDate) return true;
    if (at == null) return false;
    final DateTime local = at.toLocal();
    final DateTime from;
    final DateTime until;
    final DateTimeRange? r = range;
    if (r != null) {
      from = DateTime(r.start.year, r.start.month, r.start.day);
      until = DateTime(r.end.year, r.end.month, r.end.day + 1);
    } else {
      final DateTime now = DateTime.now();
      from = DateTime(now.year, now.month, now.day - (presetDays! - 1));
      until = DateTime(now.year, now.month, now.day + 1);
    }
    return !local.isBefore(from) && local.isBefore(until);
  }

  /// "Сүүлийн 7 хоног" or "2026.10.01 – 2026.10.25", for the active-filter pill.
  String get dateLabel {
    final DateTimeRange? r = range;
    if (r == null) {
      return AppStrings.get(
        'wallet_filter_days',
      ).replaceFirst('{n}', '$presetDays');
    }
    String d(DateTime x) =>
        '${x.year}.${x.month.toString().padLeft(2, '0')}.${x.day.toString().padLeft(2, '0')}';
    return '${d(r.start)} – ${d(r.end)}';
  }
}

/// Opens the filter sheet; resolves to the applied filter, or null if dismissed.
///
/// [showFlow] adds the income/spending choice; the charging history has no
/// use for it and leaves it out.
Future<WalletFilter?> showWalletFilterSheet(
  BuildContext context,
  WalletFilter current, {
  bool showFlow = true,
}) {
  return showModalBottomSheet<WalletFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        _WalletFilterSheet(initial: current, showFlow: showFlow),
  );
}

const List<int> _presets = <int>[7, 14, 30, 90];

class _WalletFilterSheet extends StatefulWidget {
  const _WalletFilterSheet({required this.initial, required this.showFlow});

  final WalletFilter initial;
  final bool showFlow;

  @override
  State<_WalletFilterSheet> createState() => _WalletFilterSheetState();
}

class _WalletFilterSheetState extends State<_WalletFilterSheet> {
  late int? _presetDays = widget.initial.presetDays;
  late DateTime? _start = widget.initial.range?.start;
  late DateTime? _end = widget.initial.range?.end;
  late bool _custom = widget.initial.range != null;
  late WalletFlow _flow = widget.initial.flow;
  late DateTime _month = DateTime(
    (widget.initial.range?.end ?? DateTime.now()).year,
    (widget.initial.range?.end ?? DateTime.now()).month,
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _tapDay(DateTime day) {
    setState(() {
      final DateTime? start = _start;
      if (start == null || _end != null) {
        // First tap, or starting over after a full range.
        _start = day;
        _end = null;
      } else if (day.isBefore(start)) {
        _end = start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  WalletFilter _result() {
    if (_custom && _start != null) {
      return WalletFilter(
        range: DateTimeRange(start: _start!, end: _end ?? _start!),
        flow: _flow,
      );
    }
    return WalletFilter(presetDays: _custom ? null : _presetDays, flow: _flow);
  }

  Future<void> _pickFlow() async {
    final AppPalette palette = context.palette;
    final WalletFlow? picked = await showModalBottomSheet<WalletFlow>(
      context: context,
      backgroundColor: palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final WalletFlow f in WalletFlow.values)
                ListTile(
                  title: Text(
                    _flowLabel(f),
                    style: TextStyle(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: f == _flow
                      ? Icon(Icons.check_rounded, color: palette.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(f),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _flow = picked);
  }

  static String _flowLabel(WalletFlow f) {
    switch (f) {
      case WalletFlow.all:
        return AppStrings.get('wallet_flow_all');
      case WalletFlow.income:
        return AppStrings.get('wallet_flow_income');
      case WalletFlow.expense:
        return AppStrings.get('wallet_flow_expense');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.get('wallet_filter_title'),
            style: TextStyle(
              color: palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _heading(palette, AppStrings.get('wallet_filter_by_date')),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: <Widget>[
                        for (final int days in _presets) ...<Widget>[
                          _chip(
                            palette,
                            AppStrings.get(
                              'wallet_filter_days',
                            ).replaceFirst('{n}', '$days'),
                            selected: !_custom && _presetDays == days,
                            onTap: () => setState(() {
                              _custom = false;
                              _presetDays = _presetDays == days ? null : days;
                            }),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _chip(
                          palette,
                          AppStrings.get('wallet_filter_custom'),
                          selected: _custom,
                          onTap: () => setState(() {
                            _custom = true;
                            _presetDays = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _custom
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: Column(
                              children: <Widget>[
                                _rangeField(palette),
                                const SizedBox(height: 10),
                                _calendar(palette),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (widget.showFlow) ...<Widget>[
                    const SizedBox(height: 26),
                    _heading(palette, AppStrings.get('wallet_filter_other')),
                    InkWell(
                      onTap: _pickFlow,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    AppStrings.get('wallet_filter_by_flow'),
                                    style: TextStyle(
                                      color: palette.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _flowLabel(_flow),
                                    style: TextStyle(
                                      color: _flow == WalletFlow.all
                                          ? palette.inkMuted
                                          : palette.accent,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _button(
                      palette,
                      AppStrings.get('wallet_filter_reset'),
                      primary: false,
                      onTap: () => Navigator.of(context).pop(WalletFilter.none),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _button(
                      palette,
                      AppStrings.get('wallet_filter_apply'),
                      primary: true,
                      onTap: () => Navigator.of(context).pop(_result()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(AppPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        text,
        style: TextStyle(
          color: palette.ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chip(
    AppPalette palette,
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? palette.accent : palette.ink.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : palette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rangeField(AppPalette palette) {
    String show(DateTime? d) => d == null
        ? '—'
        : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Text(
            show(_start),
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('—', style: TextStyle(color: palette.inkMuted)),
          ),
          Text(
            show(_end ?? _start),
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Icon(Icons.calendar_month_rounded, size: 20, color: palette.inkMuted),
        ],
      ),
    );
  }

  Widget _calendar(AppPalette palette) {
    final bool mn = LanguageController.current == AppLanguage.mn;
    final List<String> weekdays = mn
        ? const <String>['ДА', 'МЯ', 'ЛХ', 'ПҮ', 'БА', 'БЯ', 'НЯ']
        : const <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final DateTime today = _day(DateTime.now());
    final DateTime first = DateTime(_month.year, _month.month);
    final int lead = (first.weekday + 6) % 7;
    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final int rows = ((lead + daysInMonth) / 7).ceil();
    final DateTime? start = _start;
    final DateTime? end = _end;
    final bool canGoForward = DateTime(
      _month.year,
      _month.month + 1,
    ).isBefore(DateTime(today.year, today.month + 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: Icon(Icons.chevron_left_rounded, color: palette.ink),
              ),
              Expanded(
                child: Text(
                  _monthTitle(_month, mn),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: canGoForward
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      )
                    : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: canGoForward ? palette.ink : palette.border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdays[i],
                      style: TextStyle(
                        color: i >= 5 ? palette.accent : palette.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int row = 0; row < rows; row++)
            Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(
                      palette,
                      DateTime(
                        _month.year,
                        _month.month,
                        row * 7 + col - lead + 1,
                      ),
                      today: today,
                      start: start,
                      end: end,
                      firstCol: col == 0,
                      lastCol: col == 6,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    AppPalette palette,
    DateTime day, {
    required DateTime today,
    required DateTime? start,
    required DateTime? end,
    required bool firstCol,
    required bool lastCol,
  }) {
    final bool inMonth = day.month == _month.month;
    final bool future = day.isAfter(today);
    final bool isStart = start != null && day == start;
    final bool isEnd = end != null && day == end;
    final bool between =
        start != null && end != null && day.isAfter(start) && day.isBefore(end);
    final bool endpoint = isStart || isEnd;
    final bool hasBand = end != null && end != start;
    final Color band = palette.accent.withValues(alpha: 0.14);

    // The band joins the two endpoints, half-cells on either end.
    BoxDecoration? bandDecoration;
    if (between || (hasBand && endpoint)) {
      bandDecoration = BoxDecoration(
        gradient: isStart
            ? LinearGradient(
                colors: <Color>[Colors.transparent, band],
                stops: const <double>[0.5, 0.5],
              )
            : isEnd
            ? LinearGradient(
                colors: <Color>[band, Colors.transparent],
                stops: const <double>[0.5, 0.5],
              )
            : null,
        color: between ? band : null,
        borderRadius: BorderRadius.horizontal(
          left: firstCol && between ? const Radius.circular(20) : Radius.zero,
          right: lastCol && between ? const Radius.circular(20) : Radius.zero,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: future || !inMonth ? null : () => _tapDay(day),
      child: Container(
        height: 42,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: inMonth ? bandDecoration : null,
        alignment: Alignment.center,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: endpoint && inMonth ? palette.accent : null,
            shape: BoxShape.circle,
            border: day == today && !endpoint && inMonth
                ? Border.all(color: palette.accent.withValues(alpha: 0.6))
                : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: endpoint && inMonth
                  ? Colors.white
                  : !inMonth || future
                  ? palette.inkMuted.withValues(alpha: 0.4)
                  : palette.ink,
              fontSize: 14,
              fontWeight: endpoint ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _mnMonths = <String>[
    'Нэгдүгээр',
    'Хоёрдугаар',
    'Гуравдугаар',
    'Дөрөвдүгээр',
    'Тавдугаар',
    'Зургаадугаар',
    'Долоодугаар',
    'Наймдугаар',
    'Есдүгээр',
    'Аравдугаар',
    'Арван нэгдүгээр',
    'Арван хоёрдугаар',
  ];

  static const List<String> _enMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _monthTitle(DateTime m, bool mn) => mn
      ? '${_mnMonths[m.month - 1]} сар ${m.year}'
      : '${_enMonths[m.month - 1]} ${m.year}';

  Widget _button(
    AppPalette palette,
    String label, {
    required bool primary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: Material(
        color: primary ? palette.accent : palette.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
