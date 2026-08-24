# Driver app on the real driver API

Date: 2026-08-24
Repo: `evChargerApp`
Related: `evChargerKiosk` (driver API), `evChargerBack` (CSMS)

## Why

Login, signup, the map, the stations list and the wallet already talk to the
live driver API at `/app-api/...`. Three things do not:

1. **Charging is fabricated.** `OcppMockService` invents OCPP frames, ramps a
   battery percentage on a `Timer.periodic`, and starts every session against a
   hardcoded `'EV-UB-SHANGRILA'`. `POST /app-api/stations/:id/start` is never
   called. A driver watching the dashboard is watching a simulation.
2. **There is no station detail.** `GET /app-api/stations/:id` is never called.
   The `Station` model drops `connectors[]`, `availability`, `description`,
   `vendor`, `model`, `tags` and `lastSeenAt` — everything the kiosk's station
   page renders.
3. **Two auth flows dead-end.** The app can request a password reset but cannot
   complete one, and cannot confirm an email address.
   `POST /app-api/auth/reset-password` and `/auth/verify-email` are unwired.

## Scope

In: replacing the charging mock with real remote start/stop and real telemetry;
a station detail screen; completing the two auth flows.

Out: deep links (manual token entry instead — see Decisions); any change to
`evChargerKiosk` or `evChargerBack`; the wallet, which is already correct.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Local charging simulation | Delete entirely | A release build must never show a fake charge. No debug flag either — a simulator that can run is a simulator that will ship. |
| OCPP JSON logger sheet | Delete | It exists only to display frames the mock invents. The driver API exposes no OCPP frames, so there is nothing real to put in it. |
| Charge-limit slider, plug lock | Delete both | Neither has a driver-API endpoint; `SetChargingProfile` and `UnlockConnector` are operator-only on the CSMS. A control that visibly does nothing to the car is worse than no control. |
| Email/reset links | Manual token entry | No new dependency, no `eplug.mn` platform config, no device-only test path. Deep links are a clean follow-up once the endpoints are proven. |

## Architecture

### `ChargingController` — one source of live charging state

New: `lib/services/charging_controller.dart`. Replaces `OcppMockService` as the
thing five screens read from.

```dart
class ChargingController {
  static final ChargingController instance = ChargingController();
  ChargingController({SessionsService? sessions, StationsService? stations});

  final ValueNotifier<ChargingSession?> active;  // null == idle
  final ValueNotifier<bool> busy;                // start/stop in flight
  final ValueNotifier<String?> error;

  Future<String> start({required String stationId, int? connectorId});
  Future<String> stop();
  void beginPolling();
  void stopPolling();
}
```

**Why polling.** The driver API offers no push channel. The CSMS has
`/api/events/stream` (SSE), but it is operator-surface, JWT-gated, and the app
holds a session cookie for a different origin. So `ChargingController` polls
`GET /app-api/sessions?limit=5` and takes the entry with `status == 'Active'`.

**Cadence.** 5s while a session is active; polling is *stopped*, not slowed,
when idle or signed out. A driver with no charge running must not generate
traffic. `AuthService.currentUser` drives start/stop of the poll loop.

**Telemetry.** All of it already on the wire: `lastPowerW` → kW, `energyKwh`,
`lastSocPercent` → battery. Chargers that do not report SoC send no
`lastSocPercent`; the UI must render "—", never a guess.

**Derived range.** `remainingKm = socPercent * kmPerSocPoint`, with
`kmPerSocPoint` a named constant in one place, documented as a nominal figure
for the reference vehicle rather than a reading from the car. Shown only when
`lastSocPercent` is present.

**Start gating.** `POST /app-api/stations/:id/start` fails in three server-side
ways the app must surface verbatim rather than translate:
- `403` when `ENABLE_REMOTE_START` is off in that deployment. **The driver API
  does not expose this flag to clients** — the kiosk reads it server-side. The
  app therefore cannot pre-disable the button; it attempts the start and shows
  the returned message.
- `400` with `fields.idTag` when the account has no linked RFID tag. The app
  *can* pre-empt this: `AuthUser.idTags` is already on the session.
- Rate limit, 10/hour per user.

A `status` other than `'Accepted'` in a 200 response means the charge point
declined. Surface it as "not started", not as success.

### Station detail

`lib/models/station.dart` gains the fields both endpoints already return:

```dart
final List<StationConnector> connectors;  // empty from the list endpoint
final StationAvailability availability;   // available | busy | offline | unknown
final String? description, vendor, model, lastSeenAt;
final List<String> tags;
```

New `StationConnector` in the same file: `connectorId`, `status`
(`ConnectorStatus`), `errorCode`, `availability` (`Operative`/`Inoperative`),
`type`, `powerKw`, `currentTransactionId`, `lastPowerW`, `lastSocPercent`.

One model serves both endpoints because `/stations` and `/stations/:id` return
the same `Station` shape. The service-area coordinate filter in
`ChargingStationLocation.fromJson` stays exactly as it is — it exists because
the CSMS accepts placeholder coordinates, and that has not changed.

`StationsService.loadOne(String id)` → `GET /stations/:id`, returning a fresh
station without touching the cached list.

New `lib/screens/station_detail_screen.dart`:
- Header: name, address, availability, "N of M free", max kW, directions button
  (`url_launcher`, already a dependency).
- Connector list (`lib/widgets/connector_list.dart`, new): per row the connector
  id, plug type, kW, a status badge, and — only when the status is `Charging`,
  `SuspendedEV`, `SuspendedEVSE` or `Finishing` — live power and an SoC bar. A
  `Faulted` connector shows its `errorCode` unless that is `NoError`.
- Start card, reproducing the kiosk's gates in order: signed out → sign in; no
  linked `idTag` → link one in Account; no connector with
  `status == Available && availability == Operative` → all busy; otherwise a
  picker over the free connectors and a start button.
- A `demo: true` response is labelled as sample data, matching the kiosk.

Reached from a map marker sheet and from a stations-list row tap.

### Auth completion

`AuthService` gains:

```dart
Future<AuthUser> verifyEmail(String token);          // POST /auth/verify-email
Future<void> resetPassword({                         // POST /auth/reset-password
  String? token,                 // from an emailed link
  String? phone, String? code,   // or a 6-digit SMS code
  required String password,
  required String confirmPassword,
});
```

The API requires *either* `token` or `phone` + `code`; the screen offers both
and sends only the pair the driver filled in. Password rules and the mismatch
check are enforced server-side and reported through `ApiException.fields`, which
the existing form already renders — no client-side duplication of the rules.

New `lib/screens/reset_password_screen.dart`, chained off the existing
forgot-password step. Email verification gets a token field on the existing
account/security screen next to the "resend" action.

## Removals

| File | Fate |
| --- | --- |
| `lib/services/ocpp_mock_service.dart` | Deleted |
| `lib/widgets/ocpp_json_logger_sheet.dart` | Deleted |
| `lib/widgets/charge_limit_selector.dart` | Deleted |
| `lib/models/ocpp_models.dart` | Reduced to `ConnectorStatus`; `OcppFrame`, `OcppMessageType` and the message registry deleted |
| `test/ocpp_protocol_test.dart` | Deleted — it tests the mock's own frame registry |
| `test/charging_progress_test.dart` | Rewritten against `ChargingController` |

`lib/screens/quick_controls_screen.dart` loses the charge-limit block and the
lock tile; the climate and media tiles are untouched, being unrelated local UI.

`lib/widgets/charging_power_ring_gauge.dart` loses its `targetLimitPct`
parameter and the target arc it draws, keeping the live power ring.

Five further test files reach the mock only incidentally, through screens they
pump — `widget_test`, `map_page_navigation_test`, `theme_and_logout_test`,
`overflow_regression_test`, `language_toggle_test`, and the dashboard group in
`station_filter_test`. They are repointed at `ChargingController` (or at the
widget directly, where the mock was never the subject) rather than rewritten.
Every one must still pass; a test deleted because it broke is a test that was
telling the truth.

## Data flow

```
AuthService.currentUser ──starts/stops──> ChargingController
                                              │ 5s poll
                                              ▼
                                   GET /app-api/sessions
                                              │
                       ┌──────────────────────┴──────────────────┐
                       ▼                                          ▼
             home_dashboard_screen                      station_detail_screen
                (live gauge, stop)                    (start, connector states)
                                              ▲
                                              │
                          POST /app-api/stations/:id/start
```

`StationsService` stays the owner of the network list; `ChargingController`
owns only the session. Neither reaches into the other's state.

## Error handling

- Every failure path renders the API's own message. `ApiClient` already
  normalises `{error, fields}` and turns transport failures into
  `statusCode: 0`; nothing new is needed.
- A poll that fails does not clear `active`. Losing the network for one tick
  must not read as "your charge stopped". Three consecutive failures surface a
  stale-data notice while keeping the last known session on screen.
- A `401` from a poll stops the loop and clears state; the app frame already
  reacts to `currentUser` going null.

## Testing

Unit, with a fake `ApiClient` (the pattern in `test/support/fake_auth.dart`):
- `ChargingController` adopts an `Active` session, ignores `Completed` ones, and
  goes idle when the list has no active entry.
- A failed poll keeps the previous session; three failures raise the notice.
- `stop()` posts the active transaction id and clears state on success.
- Polling starts on sign-in and stops on sign-out.
- `Station.fromJson` parses connectors, availability and the optional fields,
  and still rejects out-of-service-area coordinates.
- `resetPassword` sends `token` alone, or `phone` + `code` alone, never both.

Widget:
- Station detail shows each of the four start-card gates for the matching state.
- A connector reports live power and SoC only in the four live statuses.
- The dashboard shows an idle state when no session is active — the regression
  the deleted mock used to cause.

Integration (`integration_test/live_backend_test.dart`, existing): extend to
assert `/stations/:id` answers for the first station the list returns.

## Risks

- **Remote start may be off in production.** If `ENABLE_REMOTE_START` is false
  on the deployed kiosk, the start button will always return 403. The feature is
  still correct; verify the flag before judging it broken.
- **Sessions need a linked `idTag`.** An account with no tag has no history and
  cannot remote-start. This is existing API behaviour, now visible rather than
  hidden behind a mock that always "worked".
- **SoC is frequently absent.** Many charge points never send it. The dashboard
  gauge must degrade to energy-only rather than showing a zero battery.

## Sequence

1. `Station` model + `StationConnector` + parsing tests.
2. `StationsService.loadOne`, station detail screen, connector list widget.
3. `ChargingController` + tests; dashboard, map and stations screens repointed.
4. Delete the mock, the logger sheet, the charge-limit selector, the dead tests.
5. Auth: `verifyEmail`, `resetPassword`, the reset screen, the verify field.
