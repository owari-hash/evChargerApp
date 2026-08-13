import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/ocpp_models.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ocpp_json_logger_sheet.dart';

class OcppProtocolSuiteScreen extends StatefulWidget {
  const OcppProtocolSuiteScreen({super.key});

  @override
  State<OcppProtocolSuiteScreen> createState() => _OcppProtocolSuiteScreenState();
}

class _OcppProtocolSuiteScreenState extends State<OcppProtocolSuiteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OcppMockService _service = OcppMockService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: OcppProfile.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OCPP 1.6J Specification',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'All 28 Protocol Messages',
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
            icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.darkForest),
            tooltip: 'View Raw JSON Logs',
            onPressed: () => OcppJsonLoggerSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.darkForest,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.sageGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: OcppProfile.values
              .map((p) => Tab(text: p.title))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: OcppProfile.values.map((profile) {
          final messages = OcppProtocolRegistry.allMessages
              .where((m) => m.profile == profile)
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msgInfo = messages[index];
              return _MessageCard(msgInfo: msgInfo);
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => OcppJsonLoggerSheet.show(context),
        backgroundColor: AppTheme.darkForest,
        icon: const Icon(Icons.code, color: Colors.white),
        label: const Text('Live JSON Inspector', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _MessageCard extends StatefulWidget {
  final OcppMessageInfo msgInfo;
  const _MessageCard({required this.msgInfo});

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  final OcppMockService _service = OcppMockService.instance;
  late TextEditingController _payloadController;
  OcppFrame? _lastResponseFrame;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _payloadController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.msgInfo.sampleRequestPayload),
    );
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _executeMessage() async {
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> parsedPayload =
          _payloadController.text.trim().isEmpty
              ? {}
              : jsonDecode(_payloadController.text);

      final response = await _service.executeOcppAction(
        widget.msgInfo.action,
        parsedPayload,
      );

      if (mounted) {
        setState(() {
          _lastResponseFrame = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResponseFrame = OcppFrame.callError(
            messageId: 'ERR-INVALID-JSON',
            action: widget.msgInfo.action,
            errorCode: 'PropertyConstraintViolation',
            errorDescription: 'Invalid JSON request string format: $e',
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCpToCs = widget.msgInfo.direction == 'CP->CS';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCpToCs
                ? AppTheme.darkForest.withOpacity(0.1)
                : AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.msgInfo.direction,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCpToCs ? AppTheme.darkForest : AppTheme.warningOrange,
            ),
          ),
        ),
        title: Text(
          widget.msgInfo.action,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkForest,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.msgInfo.summary,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payload (JSON Request Data):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkForest,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _payloadController,
                  maxLines: 5,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.softBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),

                // Trigger Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _executeMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkForest,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Sending Frame...' : 'Execute ${widget.msgInfo.action}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Response Card
                if (_lastResponseFrame != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Last Response (CALLRESULT / CALLERROR):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkForest,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F261B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      _lastResponseFrame!.toJsonString(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: _lastResponseFrame!.messageTypeId == OcppMessageType.callError
                            ? AppTheme.errorRed
                            : const Color(0xFFA9DC76),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
