import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/at_service.dart';
import '../../models/telemetry_point.dart';
import '../publisher/telemetry_streamer.dart';
import '../subscriber/telemetry_listener.dart';
import 'theme.dart';

/// Left-side peer management panel with industrial brutalist styling.
///
/// Displays:
/// - Add peer input with `@` prefix validation
/// - Live peer cards with: atSign, last coordinates, signal age, toggle sharing
/// - Streaming controls (start/stop broadcasting)
/// - Connection and telemetry status indicators
class PeerPanel extends StatefulWidget {
  final TelemetryStreamer streamer;
  final TelemetryListener listener;
  final Map<String, TelemetryPoint> latestPositions;

  const PeerPanel({
    super.key,
    required this.streamer,
    required this.listener,
    required this.latestPositions,
  });

  @override
  State<PeerPanel> createState() => _PeerPanelState();
}

class _PeerPanelState extends State<PeerPanel> {
  final TextEditingController _peerInputController = TextEditingController();
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  @override
  void dispose() {
    _peerInputController.dispose();
    super.dispose();
  }

  void _addPeer() {
    final input = _peerInputController.text.trim();
    if (input.isEmpty) return;

    final atSign = input.startsWith('@') ? input : '@$input';
    widget.streamer.addRecipient(atSign);
    _peerInputController.clear();
    setState(() {});
  }

  void _removePeer(String atSign) {
    widget.streamer.removeRecipient(atSign);
    setState(() {});
  }

  String _formatAge(DateTime timestamp) {
    final age = DateTime.now().toUtc().difference(timestamp);
    if (age.inSeconds < 60) return '${age.inSeconds}S AGO';
    if (age.inMinutes < 60) return '${age.inMinutes}M AGO';
    if (age.inHours < 24) return '${age.inHours}H AGO';
    return '${age.inDays}D AGO';
  }

  @override
  Widget build(BuildContext context) {
    final atService = AtService.instance;
    final recipients = widget.streamer.recipients.toList();

    return Container(
      decoration: AtNavTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identity Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AtNavTheme.accentOrange, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AtNav',
                  style: AtNavTheme.macroHeader(22),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      color: atService.isAuthenticated
                          ? AtNavTheme.terminalGreen
                          : AtNavTheme.accentOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      atService.currentAtSign?.toUpperCase() ?? 'NOT CONNECTED',
                      style: AtNavTheme.monoData(
                        size: 11,
                        color: atService.isAuthenticated
                            ? AtNavTheme.terminalGreen
                            : AtNavTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Streaming Controls ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AtNavTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AtNavTheme.asciiFrame('BROADCAST CONTROL'),
                  style: AtNavTheme.monoLabel(
                    size: 9,
                    color: AtNavTheme.accentOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: widget.streamer.isStreaming
                              ? widget.streamer.stopStreaming
                              : () => widget.streamer.startStreaming(),
                          style: AtNavTheme.primaryButton(
                            isDestructive: widget.streamer.isStreaming,
                          ),
                          child: Text(
                            widget.streamer.isStreaming
                                ? '/// STOP STREAM'
                                : '>>> START STREAM',
                            style: AtNavTheme.monoData(
                              size: 10,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TX: ${widget.streamer.isStreaming ? "ACTIVE" : "IDLE"}',
                      style: AtNavTheme.monoData(
                        size: 9,
                        color: widget.streamer.isStreaming
                            ? AtNavTheme.terminalGreen
                            : AtNavTheme.fgTertiary,
                      ),
                    ),
                    Text(
                      'RX: ${widget.listener.receivedCount}',
                      style: AtNavTheme.monoData(
                        size: 9,
                        color: AtNavTheme.fgSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Add Peer Input ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AtNavTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AtNavTheme.asciiFrame('ADD PEER'),
                  style: AtNavTheme.monoLabel(
                    size: 9,
                    color: AtNavTheme.accentOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _peerInputController,
                          style: AtNavTheme.monoData(size: 12),
                          decoration: AtNavTheme.inputDecoration(
                            label: '',
                            hint: '@PEER_ATSIGN',
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _addPeer(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        onPressed: _addPeer,
                        icon: const Icon(Icons.add, size: 16),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            AtNavTheme.bgElevated,
                          ),
                          shape: WidgetStateProperty.all(
                            const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: BorderSide(
                                color: AtNavTheme.borderColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Peer List Header ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AtNavTheme.bgElevated,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AtNavTheme.asciiFrame('ACTIVE PEERS'),
                  style: AtNavTheme.monoLabel(
                    size: 9,
                    color: AtNavTheme.accentOrange,
                  ),
                ),
                Text(
                  '${recipients.length} LINKED',
                  style: AtNavTheme.monoData(
                    size: 9,
                    color: AtNavTheme.fgTertiary,
                  ),
                ),
              ],
            ),
          ),

          // ── Peer List ──────────────────────────────────────────────
          Expanded(
            child: recipients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '< NO PEERS >',
                          style: AtNavTheme.monoData(
                            size: 12,
                            color: AtNavTheme.fgTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ADD AN ATSIGN TO BEGIN SHARING',
                          style: AtNavTheme.monoLabel(
                            size: 9,
                            color: AtNavTheme.fgTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: recipients.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AtNavTheme.borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final peer = recipients[index];
                      final position = widget.latestPositions[peer];
                      final hasData = position != null;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        color: AtNavTheme.bgSurface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: hasData
                                        ? AtNavTheme.accentOrange
                                        : AtNavTheme.fgTertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    peer.toUpperCase(),
                                    style: AtNavTheme.monoData(
                                      size: 12,
                                      weight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _removePeer(peer),
                                  child: Text(
                                    '[X]',
                                    style: AtNavTheme.monoData(
                                      size: 10,
                                      color: AtNavTheme.accentOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasData) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'LAT ${position.latitude.toStringAsFixed(6)}',
                                    style: AtNavTheme.monoData(
                                      size: 10,
                                      color: AtNavTheme.fgSecondary,
                                    ),
                                  ),
                                  Text(
                                    'LNG ${position.longitude.toStringAsFixed(6)}',
                                    style: AtNavTheme.monoData(
                                      size: 10,
                                      color: AtNavTheme.fgSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _timeFormat.format(
                                      position.timestamp.toLocal(),
                                    ),
                                    style: AtNavTheme.monoLabel(
                                      size: 9,
                                      color: AtNavTheme.fgTertiary,
                                    ),
                                  ),
                                  Text(
                                    _formatAge(position.timestamp),
                                    style: AtNavTheme.monoLabel(
                                      size: 9,
                                      color: AtNavTheme.fgTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'AWAITING TELEMETRY...',
                                style: AtNavTheme.monoLabel(
                                  size: 9,
                                  color: AtNavTheme.fgTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
