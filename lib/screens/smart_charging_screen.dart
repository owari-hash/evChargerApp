import 'package:flutter/material.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ocpp_json_logger_sheet.dart';

class SmartChargingScreen extends StatefulWidget {
  const SmartChargingScreen({super.key});

  @override
  State<SmartChargingScreen> createState() => _SmartChargingScreenState();
}

class _SmartChargingScreenState extends State<SmartChargingScreen> {
  final OcppMockService _service = OcppMockService.instance;

  double _maxCurrentLimit = 32.0; // Amperes
  String _rateUnit = 'A'; // 'A' or 'W'
  String _purpose = 'TxDefaultProfile'; // TxDefaultProfile, TxProfile, ChargePointMaxProfile

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OCPP 1.6 Profile 5',
              style: TextStyle(
                fontSize: 12,
                color: context.palette.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Smart Charging Manager',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.palette.ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.code_rounded, color: context.palette.ink),
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
            // Header Description Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.palette.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppTheme.sageGreen, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Load Balancing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configure SetChargingProfile & GetCompositeSchedule for optimized energy management.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Purpose Selector Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Charging Profile Purpose',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _purpose,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.palette.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.palette.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TxDefaultProfile',
                        child: Text('TxDefaultProfile (Connector Default Schedule)'),
                      ),
                      DropdownMenuItem(
                        value: 'TxProfile',
                        child: Text('TxProfile (Active Transaction Limit)'),
                      ),
                      DropdownMenuItem(
                        value: 'ChargePointMaxProfile',
                        child: Text('ChargePointMaxProfile (Station Max Power)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _purpose = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Power Unit Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Charging Rate Unit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.ink,
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'A', label: Text('Amperes (A)')),
                          ButtonSegment(value: 'W', label: Text('Watts (W)')),
                        ],
                        selected: {_rateUnit},
                        onSelectionChanged: (val) {
                          setState(() => _rateUnit = val.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Slider
                  Text(
                    'Max Limit: ${_maxCurrentLimit.toInt()} $_rateUnit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.palette.ink,
                    ),
                  ),
                  Slider(
                    value: _maxCurrentLimit,
                    min: 6.0,
                    max: 64.0,
                    divisions: 58,
                    activeColor: AppTheme.sageGreen,
                    inactiveColor: context.palette.accent.withValues(alpha: 0.16),
                    label: '${_maxCurrentLimit.toInt()} $_rateUnit',
                    onChanged: (val) {
                      setState(() => _maxCurrentLimit = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Submit Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _service.executeOcppAction('SetChargingProfile', {
                              'connectorId': 1,
                              'csChargingProfiles': {
                                'chargingProfileId': 12,
                                'stackLevel': 1,
                                'chargingProfilePurpose': _purpose,
                                'chargingProfileKind': 'Recurring',
                                'recurrencyKind': 'Daily',
                                'chargingSchedule': {
                                  'chargingRateUnit': _rateUnit,
                                  'chargingSchedulePeriod': [
                                    {'startPeriod': 0, 'limit': _maxCurrentLimit}
                                  ]
                                }
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OCPP SetChargingProfile sent!')),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Apply Profile'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          _service.executeOcppAction('ClearChargingProfile', {
                            'connectorId': 1,
                            'chargingProfilePurpose': _purpose,
                          });
                        },
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Get Composite Schedule Action Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Composite Schedule Query',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fetch combined calculated schedule limit for next 24 hours.',
                    style: TextStyle(fontSize: 12, color: context.palette.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _service.executeOcppAction('GetCompositeSchedule', {
                          'connectorId': 1,
                          'duration': 86400,
                          'chargingRateUnit': _rateUnit,
                        });
                        OcppJsonLoggerSheet.show(context);
                      },
                      icon: Icon(Icons.analytics_rounded, color: context.palette.ink),
                      label: const Text('Query GetCompositeSchedule'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
