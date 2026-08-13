import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ocpp_models.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';

class OcppJsonLoggerSheet extends StatefulWidget {
  const OcppJsonLoggerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OcppJsonLoggerSheet(),
    );
  }

  @override
  State<OcppJsonLoggerSheet> createState() => _OcppJsonLoggerSheetState();
}

class _OcppJsonLoggerSheetState extends State<OcppJsonLoggerSheet> {
  final OcppMockService _service = OcppMockService.instance;
  String _searchFilter = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.darkForest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, color: AppTheme.sageGreen, size: 24),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCPP 1.6J Frame Inspector',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'WebSocket JSON-RPC Frames [2=CALL, 3=RESULT, 4=ERROR]',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                  onPressed: () {
                    _service.clearLogs();
                    setState(() {});
                  },
                  tooltip: 'Clear Logs',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Filter Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() => _searchFilter = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Filter by Action or Message ID...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.sageGreen, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Log List
          Expanded(
            child: StreamBuilder<List<OcppFrame>>(
              stream: _service.logStream,
              initialData: _service.logs,
              builder: (context, snapshot) {
                final logs = (snapshot.data ?? [])
                    .where((frame) {
                      if (_searchFilter.isEmpty) return true;
                      final String action = frame.action?.toLowerCase() ?? '';
                      final String msgId = frame.messageId.toLowerCase();
                      final String payload = jsonEncode(frame.payload).toLowerCase();
                      return action.contains(_searchFilter) ||
                          msgId.contains(_searchFilter) ||
                          payload.contains(_searchFilter);
                    })
                    .toList();

                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No OCPP frames recorded yet.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final frame = logs[index];
                    return _buildFrameCard(frame);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCard(OcppFrame frame) {
    final bool isCall = frame.messageTypeId == OcppMessageType.call;
    final bool isResult = frame.messageTypeId == OcppMessageType.callResult;

    final Color badgeColor = isCall
        ? const Color(0xFF3498DB)
        : isResult
            ? AppTheme.sageGreen
            : AppTheme.errorRed;

    final String typeLabel = isCall
        ? 'CALL [2]'
        : isResult
            ? 'CALLRESULT [3]'
            : 'CALLERROR [4]';

    final String jsonStr = const JsonEncoder.withIndent('  ').convert(
      isCall
          ? [2, frame.messageId, frame.action ?? '', frame.payload]
          : isResult
              ? [3, frame.messageId, frame.payload]
              : [4, frame.messageId, frame.errorCode ?? 'GenericError', frame.errorDescription ?? '', frame.payload],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF133523),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                frame.action ?? 'Response',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${frame.timestamp.hour.toString().padLeft(2, '0')}:${frame.timestamp.minute.toString().padLeft(2, '0')}:${frame.timestamp.second.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Raw JSON copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy_rounded, color: Colors.white54, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF09170F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                jsonStr,
                style: const TextStyle(
                  color: Color(0xFFA9DC76),
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
