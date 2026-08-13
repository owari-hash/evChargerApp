import 'package:flutter/material.dart';
import '../models/ocpp_models.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ocpp_json_logger_sheet.dart';

class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({super.key});

  @override
  State<StationManagementScreen> createState() => _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  final OcppMockService _service = OcppMockService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station & Connector Control',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'OCPP Connector Grid',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkForest,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.code_rounded, color: AppTheme.darkForest),
            onPressed: () => OcppJsonLoggerSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkForest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.ev_station_rounded,
                            color: AppTheme.sageGreen, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _service.chargePointId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'OCPP 1.6 Edition 2 • WebSocket Online',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: () {
                            _service.executeOcppAction('Reset', {'type': 'Soft'});
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Soft Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: () {
                            _service.executeOcppAction('BootNotification', {
                              'chargePointVendor': 'EVTech Pro',
                              'chargePointModel': 'UltraCharge X500',
                            });
                          },
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: const Text('Boot Notify'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Connector Statuses (OCPP StatusNotification)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkForest,
              ),
            ),
            const SizedBox(height: 12),

            // Connector 1 Card (CCS2 DC Fast)
            _buildConnectorTile(
              connectorId: 1,
              title: 'Connector 1 — CCS2 DC Fast (150kW)',
              status: _service.connectorStatuses[1] ?? ConnectorStatus.charging,
            ),
            const SizedBox(height: 14),

            // Connector 2 Card (Type 2 AC)
            _buildConnectorTile(
              connectorId: 2,
              title: 'Connector 2 — Type 2 AC (22kW)',
              status: _service.connectorStatuses[2] ?? ConnectorStatus.available,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectorTile({
    required int connectorId,
    required String title,
    required ConnectorStatus status,
  }) {
    final Color badgeColor = status == ConnectorStatus.charging
        ? AppTheme.sageGreen
        : status == ConnectorStatus.available
            ? const Color(0xFF2980B9)
            : status == ConnectorStatus.faulted
                ? AppTheme.errorRed
                : AppTheme.warningOrange;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkForest,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  status.code,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Change Status Selector
          DropdownButtonFormField<ConnectorStatus>(
            value: status,
            decoration: InputDecoration(
              labelText: 'Simulate Status Change',
              filled: true,
              fillColor: AppTheme.softBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: ConnectorStatus.values
                .map((st) => DropdownMenuItem(
                      value: st,
                      child: Text('${st.code} — ${st.label}'),
                    ))
                .toList(),
            onChanged: (newStatus) {
              if (newStatus != null) {
                setState(() {
                  _service.connectorStatuses[connectorId] = newStatus;
                });
                _service.executeOcppAction('StatusNotification', {
                  'connectorId': connectorId,
                  'errorCode': newStatus == ConnectorStatus.faulted
                      ? 'GroundFailure'
                      : 'NoError',
                  'status': newStatus.code,
                  'timestamp': DateTime.now().toIso8601String(),
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Quick Action buttons for connector
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _service.executeOcppAction('UnlockConnector', {
                      'connectorId': connectorId,
                    });
                  },
                  child: const Text('Unlock Cable'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _service.executeOcppAction('ChangeAvailability', {
                      'connectorId': connectorId,
                      'type': status == ConnectorStatus.unavailable
                          ? 'Operative'
                          : 'Inoperative',
                    });
                  },
                  child: Text(status == ConnectorStatus.unavailable
                      ? 'Make Operative'
                      : 'Set Inoperative'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
