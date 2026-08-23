import 'dart:convert';

/// OCPP 1.6 Feature Profiles
enum OcppProfile {
  core(
    'Core',
    'Core operations: boot, status, authorize, transactions, config',
  ),
  firmware(
    'Firmware Management',
    'Firmware download, update status, diagnostics',
  ),
  localAuthList(
    'Local Auth List',
    'Local whitelist management and list versioning',
  ),
  reservation('Reservation', 'Reserve connector & cancel reservation'),
  smartCharging(
    'Smart Charging',
    'Set/clear charging profiles & composite schedules',
  ),
  remoteTrigger('Remote Trigger', 'Trigger specific CP messages on-demand');

  final String title;
  final String description;
  const OcppProfile(this.title, this.description);
}

/// OCPP 1.6 Connector Statuses (9 statuses)
enum ConnectorStatus {
  available('Available', 'Available for charging session'),
  preparing('Preparing', 'Occupied, authenticating or waiting for cable plug'),
  charging('Charging', 'Energy actively transferring to EV'),
  suspendedEV('SuspendedEV', 'EV requested pause in charging'),
  suspendedEVSE(
    'SuspendedEVSE',
    'Station paused charging (smart charging limit)',
  ),
  finishing('Finishing', 'Session stopped, awaiting cable disconnect'),
  reserved('Reserved', 'Connector reserved for specific user ID'),
  unavailable('Unavailable', 'Set to inoperative'),
  faulted('Faulted', 'Connector in error state');

  final String code;
  final String label;
  const ConnectorStatus(this.code, this.label);

  static ConnectorStatus fromCode(String code) {
    return ConnectorStatus.values.firstWhere(
      (e) => e.code.toLowerCase() == code.toLowerCase(),
      orElse: () => ConnectorStatus.available,
    );
  }
}

/// OCPP 1.6 Frame Type Constants
class OcppMessageType {
  static const int call = 2;
  static const int callResult = 3;
  static const int callError = 4;
}

/// OCPP 1.6J Message Frame Representation
class OcppFrame {
  final int messageTypeId;
  final String messageId;
  final String? action;
  final Map<String, dynamic> payload;
  final String? errorCode;
  final String? errorDescription;
  final DateTime timestamp;

  OcppFrame({
    required this.messageTypeId,
    required this.messageId,
    this.action,
    required this.payload,
    this.errorCode,
    this.errorDescription,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a CALL (Request) frame
  factory OcppFrame.call({
    required String messageId,
    required String action,
    required Map<String, dynamic> payload,
  }) {
    return OcppFrame(
      messageTypeId: OcppMessageType.call,
      messageId: messageId,
      action: action,
      payload: payload,
    );
  }

  /// Create a CALLRESULT (Response) frame
  factory OcppFrame.callResult({
    required String messageId,
    required Map<String, dynamic> payload,
    String? action,
  }) {
    return OcppFrame(
      messageTypeId: OcppMessageType.callResult,
      messageId: messageId,
      action: action,
      payload: payload,
    );
  }

  /// Create a CALLERROR frame
  factory OcppFrame.callError({
    required String messageId,
    required String errorCode,
    required String errorDescription,
    Map<String, dynamic>? errorDetails,
    String? action,
  }) {
    return OcppFrame(
      messageTypeId: OcppMessageType.callError,
      messageId: messageId,
      action: action,
      payload: errorDetails ?? {},
      errorCode: errorCode,
      errorDescription: errorDescription,
    );
  }

  /// Serialize to OCPP 1.6J raw JSON string format [type, id, ...]
  String toJsonString() {
    if (messageTypeId == OcppMessageType.call) {
      return jsonEncode([messageTypeId, messageId, action, payload]);
    } else if (messageTypeId == OcppMessageType.callResult) {
      return jsonEncode([messageTypeId, messageId, payload]);
    } else {
      return jsonEncode([
        messageTypeId,
        messageId,
        errorCode ?? 'GenericError',
        errorDescription ?? '',
        payload,
      ]);
    }
  }

  /// Parse from OCPP 1.6J JSON array string
  static OcppFrame fromJsonString(String rawJson, {String? defaultAction}) {
    final List<dynamic> list = jsonDecode(rawJson);
    final int type = list[0] as int;
    final String msgId = list[1].toString();

    if (type == OcppMessageType.call) {
      return OcppFrame.call(
        messageId: msgId,
        action: list[2].toString(),
        payload: (list[3] as Map<String, dynamic>? ?? {}),
      );
    } else if (type == OcppMessageType.callResult) {
      return OcppFrame.callResult(
        messageId: msgId,
        action: defaultAction,
        payload: (list[2] as Map<String, dynamic>? ?? {}),
      );
    } else {
      return OcppFrame.callError(
        messageId: msgId,
        action: defaultAction,
        errorCode: list[2].toString(),
        errorDescription: list[3].toString(),
        errorDetails:
            (list.length > 4 ? list[4] as Map<String, dynamic>? : {}) ?? {},
      );
    }
  }
}

/// Information descriptor for all 28 OCPP 1.6 Messages
class OcppMessageInfo {
  final String action;
  final OcppProfile profile;
  final String direction; // 'CP->CS', 'CS->CP', or 'Both'
  final String summary;
  final Map<String, dynamic> sampleRequestPayload;
  final Map<String, dynamic> sampleResponsePayload;

  const OcppMessageInfo({
    required this.action,
    required this.profile,
    required this.direction,
    required this.summary,
    required this.sampleRequestPayload,
    required this.sampleResponsePayload,
  });
}

/// Registry of all 28 Messages defined in OCPP 1.6J Specification
class OcppProtocolRegistry {
  static const List<OcppMessageInfo> allMessages = [
    // --- 1. CORE PROFILE (16 Messages) ---
    OcppMessageInfo(
      action: 'Authorize',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Validate an idTag before starting a transaction.',
      sampleRequestPayload: {'idTag': 'RFID_TAG_99812'},
      sampleResponsePayload: {
        'idTagInfo': {
          'status': 'Accepted',
          'expiryDate': '2026-12-31T23:59:59Z',
          'parentIdTag': 'PARENT_ACCOUNT_1',
        },
      },
    ),
    OcppMessageInfo(
      action: 'BootNotification',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary:
          'Sent on charge point boot. CS responds with status and heartbeat interval.',
      sampleRequestPayload: {
        'chargePointVendor': 'EVTech Pro',
        'chargePointModel': 'UltraCharge X500',
        'chargePointSerialNumber': 'EV-SN-2026-88',
        'firmwareVersion': 'v2.4.12-release',
      },
      sampleResponsePayload: {
        'status': 'Accepted',
        'currentTime': '2026-08-13T20:53:00Z',
        'interval': 300,
      },
    ),
    OcppMessageInfo(
      action: 'ChangeAvailability',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Set a connector or full station to Operative or Inoperative.',
      sampleRequestPayload: {'connectorId': 1, 'type': 'Operative'},
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'ChangeConfiguration',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Write a configuration key on the Charge Point.',
      sampleRequestPayload: {'key': 'MeterValueSampleInterval', 'value': '60'},
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'ClearCache',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Clear local authorization cache.',
      sampleRequestPayload: {},
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'DataTransfer',
      profile: OcppProfile.core,
      direction: 'Both',
      summary: 'Vendor-specific data exchange.',
      sampleRequestPayload: {
        'vendorId': 'com.evtech',
        'messageId': 'GetTelemetry',
        'data': 'raw_custom_payload',
      },
      sampleResponsePayload: {
        'status': 'Accepted',
        'data': 'response_telemetry_data',
      },
    ),
    OcppMessageInfo(
      action: 'GetConfiguration',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Read configuration keys from the Charge Point.',
      sampleRequestPayload: {
        'key': [
          'HeartbeatInterval',
          'ConnectionTimeOut',
          'MeterValueSampleInterval',
        ],
      },
      sampleResponsePayload: {
        'configurationKey': [
          {'key': 'HeartbeatInterval', 'readonly': false, 'value': '300'},
          {'key': 'ConnectionTimeOut', 'readonly': false, 'value': '60'},
          {'key': 'MeterValueSampleInterval', 'readonly': false, 'value': '30'},
        ],
        'unknownKey': [],
      },
    ),
    OcppMessageInfo(
      action: 'Heartbeat',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Periodic keepalive message.',
      sampleRequestPayload: {},
      sampleResponsePayload: {'currentTime': '2026-08-13T20:55:00Z'},
    ),
    OcppMessageInfo(
      action: 'MeterValues',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Send periodic energy readings for a connector.',
      sampleRequestPayload: {
        'connectorId': 1,
        'transactionId': 10042,
        'meterValue': [
          {
            'timestamp': '2026-08-13T20:55:10Z',
            'sampledValue': [
              {
                'value': '18500',
                'context': 'Sample.Periodic',
                'format': 'Raw',
                'measurand': 'Energy.Active.Import.Register',
                'unit': 'Wh',
              },
              {
                'value': '230.5',
                'context': 'Sample.Periodic',
                'format': 'Raw',
                'measurand': 'Voltage',
                'unit': 'V',
              },
              {
                'value': '32.0',
                'context': 'Sample.Periodic',
                'format': 'Raw',
                'measurand': 'Current.Import',
                'unit': 'A',
              },
            ],
          },
        ],
      },
      sampleResponsePayload: {},
    ),
    OcppMessageInfo(
      action: 'RemoteStartTransaction',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Remotely command station to start charging session.',
      sampleRequestPayload: {
        'connectorId': 1,
        'idTag': 'REMOTE_USR_402',
        'chargingProfile': {
          'chargingProfileId': 101,
          'stackLevel': 1,
          'chargingProfilePurpose': 'TxProfile',
          'chargingProfileKind': 'Absolute',
          'chargingSchedule': {
            'chargingRateUnit': 'W',
            'chargingSchedulePeriod': [
              {'startPeriod': 0, 'limit': 22000},
            ],
          },
        },
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'RemoteStopTransaction',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Remotely stop an active charging transaction.',
      sampleRequestPayload: {'transactionId': 10042},
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'Reset',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Reboot the Charge Point (Hard or Soft).',
      sampleRequestPayload: {'type': 'Soft'},
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'StartTransaction',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Notify CS that charging transaction has initiated.',
      sampleRequestPayload: {
        'connectorId': 1,
        'idTag': 'RFID_TAG_99812',
        'meterStart': 12400,
        'timestamp': '2026-08-13T20:50:00Z',
      },
      sampleResponsePayload: {
        'transactionId': 10042,
        'idTagInfo': {
          'status': 'Accepted',
          'expiryDate': '2026-12-31T23:59:59Z',
        },
      },
    ),
    OcppMessageInfo(
      action: 'StatusNotification',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Report current status and error code of a connector.',
      sampleRequestPayload: {
        'connectorId': 1,
        'errorCode': 'NoError',
        'status': 'Charging',
        'timestamp': '2026-08-13T20:50:05Z',
        'info': 'Normal charging operation',
      },
      sampleResponsePayload: {},
    ),
    OcppMessageInfo(
      action: 'StopTransaction',
      profile: OcppProfile.core,
      direction: 'CP->CS',
      summary: 'Notify CS that transaction has completed.',
      sampleRequestPayload: {
        'transactionId': 10042,
        'idTag': 'RFID_TAG_99812',
        'meterStop': 18500,
        'timestamp': '2026-08-13T21:30:00Z',
        'reason': 'Local',
      },
      sampleResponsePayload: {
        'idTagInfo': {'status': 'Accepted'},
      },
    ),
    OcppMessageInfo(
      action: 'UnlockConnector',
      profile: OcppProfile.core,
      direction: 'CS->CP',
      summary: 'Remotely unlock cable plug lock on connector.',
      sampleRequestPayload: {'connectorId': 1},
      sampleResponsePayload: {'status': 'Unlocked'},
    ),

    // --- 2. FIRMWARE MANAGEMENT (4 Messages) ---
    OcppMessageInfo(
      action: 'GetDiagnostics',
      profile: OcppProfile.firmware,
      direction: 'CS->CP',
      summary: 'Request diagnostic log upload to URL.',
      sampleRequestPayload: {
        'location': 'ftp://upload.evtech.com/logs/',
        'retries': 3,
        'retryInterval': 60,
      },
      sampleResponsePayload: {'fileName': 'log_EV-SN-2026-88_20260813.txt'},
    ),
    OcppMessageInfo(
      action: 'DiagnosticsStatusNotification',
      profile: OcppProfile.firmware,
      direction: 'CP->CS',
      summary: 'Report status of diagnostic file upload.',
      sampleRequestPayload: {'status': 'Uploaded'},
      sampleResponsePayload: {},
    ),
    OcppMessageInfo(
      action: 'UpdateFirmware',
      profile: OcppProfile.firmware,
      direction: 'CS->CP',
      summary: 'Instruct CP to download & install firmware from URL.',
      sampleRequestPayload: {
        'location': 'https://firmware.evtech.com/bin/v2.5.0.bin',
        'retrieveDate': '2026-08-14T02:00:00Z',
        'retries': 3,
        'retryInterval': 300,
      },
      sampleResponsePayload: {},
    ),
    OcppMessageInfo(
      action: 'FirmwareStatusNotification',
      profile: OcppProfile.firmware,
      direction: 'CP->CS',
      summary: 'Report firmware update progress.',
      sampleRequestPayload: {'status': 'Downloaded'},
      sampleResponsePayload: {},
    ),

    // --- 3. LOCAL AUTH LIST MANAGEMENT (2 Messages) ---
    OcppMessageInfo(
      action: 'SendLocalList',
      profile: OcppProfile.localAuthList,
      direction: 'CS->CP',
      summary: 'Send local authorization list (Full or Differential update).',
      sampleRequestPayload: {
        'listVersion': 2,
        'updateType': 'Full',
        'localAuthorizationList': [
          {
            'idTag': 'LOCAL_CARD_1',
            'idTagInfo': {
              'status': 'Accepted',
              'expiryDate': '2027-01-01T00:00:00Z',
            },
          },
          {
            'idTag': 'LOCAL_CARD_2',
            'idTagInfo': {'status': 'Blocked'},
          },
        ],
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'GetLocalListVersion',
      profile: OcppProfile.localAuthList,
      direction: 'CS->CP',
      summary: 'Query current local authorization list version number.',
      sampleRequestPayload: {},
      sampleResponsePayload: {'listVersion': 2},
    ),

    // --- 4. RESERVATION (2 Messages) ---
    OcppMessageInfo(
      action: 'ReserveNow',
      profile: OcppProfile.reservation,
      direction: 'CS->CP',
      summary: 'Reserve connector for specific idTag until expiry time.',
      sampleRequestPayload: {
        'connectorId': 1,
        'expiryDate': '2026-08-13T22:00:00Z',
        'idTag': 'RESERVE_USR_55',
        'reservationId': 501,
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'CancelReservation',
      profile: OcppProfile.reservation,
      direction: 'CS->CP',
      summary: 'Cancel active reservation by reservationId.',
      sampleRequestPayload: {'reservationId': 501},
      sampleResponsePayload: {'status': 'Accepted'},
    ),

    // --- 5. SMART CHARGING (3 Messages) ---
    OcppMessageInfo(
      action: 'SetChargingProfile',
      profile: OcppProfile.smartCharging,
      direction: 'CS->CP',
      summary: 'Set power or current limits schedule on connector.',
      sampleRequestPayload: {
        'connectorId': 1,
        'csChargingProfiles': {
          'chargingProfileId': 12,
          'stackLevel': 0,
          'chargingProfilePurpose': 'TxDefaultProfile',
          'chargingProfileKind': 'Recurring',
          'recurrencyKind': 'Daily',
          'chargingSchedule': {
            'chargingRateUnit': 'A',
            'chargingSchedulePeriod': [
              {'startPeriod': 0, 'limit': 32.0},
              {'startPeriod': 28800, 'limit': 16.0},
              {'startPeriod': 72000, 'limit': 32.0},
            ],
          },
        },
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'ClearChargingProfile',
      profile: OcppProfile.smartCharging,
      direction: 'CS->CP',
      summary: 'Clear charging profile(s) by criteria.',
      sampleRequestPayload: {
        'id': 12,
        'connectorId': 1,
        'chargingProfilePurpose': 'TxDefaultProfile',
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
    OcppMessageInfo(
      action: 'GetCompositeSchedule',
      profile: OcppProfile.smartCharging,
      direction: 'CS->CP',
      summary: 'Request effective calculated combined schedule for connector.',
      sampleRequestPayload: {
        'connectorId': 1,
        'duration': 86400,
        'chargingRateUnit': 'A',
      },
      sampleResponsePayload: {
        'status': 'Accepted',
        'connectorId': 1,
        'scheduleStart': '2026-08-13T20:55:00Z',
        'chargingSchedule': {
          'chargingRateUnit': 'A',
          'chargingSchedulePeriod': [
            {'startPeriod': 0, 'limit': 32.0},
            {'startPeriod': 28800, 'limit': 16.0},
          ],
        },
      },
    ),

    // --- 6. REMOTE TRIGGER (1 Message) ---
    OcppMessageInfo(
      action: 'TriggerMessage',
      profile: OcppProfile.remoteTrigger,
      direction: 'CS->CP',
      summary: 'Ask Charge Point to emit a specific message.',
      sampleRequestPayload: {
        'requestedMessage': 'BootNotification',
        'connectorId': 0,
      },
      sampleResponsePayload: {'status': 'Accepted'},
    ),
  ];

  static OcppMessageInfo findByAction(String action) {
    return allMessages.firstWhere(
      (m) => m.action.toLowerCase() == action.toLowerCase(),
      orElse: () => allMessages.first,
    );
  }
}
