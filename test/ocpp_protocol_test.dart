import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/models/ocpp_models.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';

void main() {
  group('OCPP 1.6J Protocol Specification & Data Models Test Suite', () {
    test('Verify all 6 Feature Profiles are registered', () {
      expect(OcppProfile.values.length, equals(6));
      expect(OcppProfile.values.map((e) => e.title), containsAll([
        'Core',
        'Firmware Management',
        'Local Auth List',
        'Reservation',
        'Smart Charging',
        'Remote Trigger',
      ]));
    });

    test('Verify registry contains exactly all 28 OCPP 1.6 messages', () {
      final messages = OcppProtocolRegistry.allMessages;
      expect(messages.length, equals(28));

      // Core profile (16 messages)
      final coreMsgs = messages.where((m) => m.profile == OcppProfile.core).toList();
      expect(coreMsgs.length, equals(16));
      expect(
        coreMsgs.map((m) => m.action),
        containsAll([
          'Authorize',
          'BootNotification',
          'ChangeAvailability',
          'ChangeConfiguration',
          'ClearCache',
          'DataTransfer',
          'GetConfiguration',
          'Heartbeat',
          'MeterValues',
          'RemoteStartTransaction',
          'RemoteStopTransaction',
          'Reset',
          'StartTransaction',
          'StatusNotification',
          'StopTransaction',
          'UnlockConnector',
        ]),
      );

      // Firmware profile (4 messages)
      final firmwareMsgs = messages.where((m) => m.profile == OcppProfile.firmware).toList();
      expect(firmwareMsgs.length, equals(4));

      // Local Auth List profile (2 messages)
      final localAuthMsgs = messages.where((m) => m.profile == OcppProfile.localAuthList).toList();
      expect(localAuthMsgs.length, equals(2));

      // Reservation profile (2 messages)
      final reservationMsgs = messages.where((m) => m.profile == OcppProfile.reservation).toList();
      expect(reservationMsgs.length, equals(2));

      // Smart Charging profile (3 messages)
      final smartChargingMsgs = messages.where((m) => m.profile == OcppProfile.smartCharging).toList();
      expect(smartChargingMsgs.length, equals(3));

      // Remote Trigger profile (1 message)
      final remoteTriggerMsgs = messages.where((m) => m.profile == OcppProfile.remoteTrigger).toList();
      expect(remoteTriggerMsgs.length, equals(1));
    });

    test('Verify all 9 Connector Status values match OCPP 1.6 spec', () {
      expect(ConnectorStatus.values.length, equals(9));
      final codes = ConnectorStatus.values.map((s) => s.code).toList();
      expect(codes, containsAll([
        'Available',
        'Preparing',
        'Charging',
        'SuspendedEV',
        'SuspendedEVSE',
        'Finishing',
        'Reserved',
        'Unavailable',
        'Faulted',
      ]));
    });

    test('OCPP 1.6J JSON-RPC Frame Serialization & Parsing Test', () {
      // Test CALL frame [2, "MSG-101", "BootNotification", {...}]
      final callFrame = OcppFrame.call(
        messageId: 'MSG-101',
        action: 'BootNotification',
        payload: {'chargePointVendor': 'EVTech', 'chargePointModel': 'ModelX'},
      );
      final String callJson = callFrame.toJsonString();
      expect(callJson, contains('[2,"MSG-101","BootNotification"'));

      final parsedCall = OcppFrame.fromJsonString(callJson);
      expect(parsedCall.messageTypeId, equals(2));
      expect(parsedCall.messageId, equals('MSG-101'));
      expect(parsedCall.action, equals('BootNotification'));
      expect(parsedCall.payload['chargePointVendor'], equals('EVTech'));

      // Test CALLRESULT frame [3, "MSG-101", {...}]
      final resultFrame = OcppFrame.callResult(
        messageId: 'MSG-101',
        action: 'BootNotification',
        payload: {'status': 'Accepted', 'interval': 300},
      );
      final String resultJson = resultFrame.toJsonString();
      expect(resultJson, contains('[3,"MSG-101"'));

      final parsedResult = OcppFrame.fromJsonString(resultJson, defaultAction: 'BootNotification');
      expect(parsedResult.messageTypeId, equals(3));
      expect(parsedResult.messageId, equals('MSG-101'));
      expect(parsedResult.payload['status'], equals('Accepted'));

      // Test CALLERROR frame [4, "MSG-101", "NotImplemented", "Desc", {...}]
      final errorFrame = OcppFrame.callError(
        messageId: 'MSG-101',
        action: 'CustomAction',
        errorCode: 'NotImplemented',
        errorDescription: 'Action not supported',
      );
      final String errorJson = errorFrame.toJsonString();
      expect(errorJson, contains('[4,"MSG-101","NotImplemented"'));
    });
  });

  group('OCPP 1.6J Service Execution Test Suite (All 28 Actions)', () {
    final service = OcppMockService.instance;

    for (final msg in OcppProtocolRegistry.allMessages) {
      test('Execute message: ${msg.action} (${msg.profile.title})', () async {
        final response = await service.executeOcppAction(
          msg.action,
          msg.sampleRequestPayload,
        );

        expect(response.messageTypeId, isIn([OcppMessageType.callResult, OcppMessageType.callError]));
        expect(response.action, equals(msg.action));

        // Check raw log contains both request CALL and response
        final logs = service.logs;
        expect(logs.any((f) => f.action == msg.action), isTrue);
      });
    }
  });

  group('Connector Lifecycle & State Transition Test', () {
    final service = OcppMockService.instance;

    test('State transition: Start & Stop transaction updates status', () async {
      // Start transaction on connector 1
      await service.executeOcppAction('StartTransaction', {
        'connectorId': 1,
        'idTag': 'TEST_CARD',
        'meterStart': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });

      expect(service.connectorStatuses[1], equals(ConnectorStatus.charging));

      // Stop transaction
      await service.executeOcppAction('StopTransaction', {
        'transactionId': service.activeTransactionId,
        'meterStop': 1500,
        'timestamp': DateTime.now().toIso8601String(),
        'reason': 'Local',
      });

      expect(service.connectorStatuses[1], equals(ConnectorStatus.finishing));
    });
  });
}
