import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/at_service.dart';
import '../../models/telemetry_point.dart';
import '../publisher/telemetry_streamer.dart';
import '../subscriber/telemetry_listener.dart';
import '../storage/local_db.dart';
import 'theme.dart';

/// Left-side peer management panel with industrial brutalist styling.
///
/// Displays:
/// - Add peer input with `@` prefix validation
/// - Live peer cards with: atSign, last coordinates, signal age, toggle sharing
/// - Streaming controls (start/stop broadcasting)
/// - Connection and telemetry status indicators
///
/// When used inside a [DraggableScrollableSheet], pass its [scrollController]
/// so the sheet's drag gesture is linked to the list scroll.
class PeerPanel extends StatefulWidget {
  final TelemetryStreamer streamer;
  final TelemetryListener listener;
  final Map<String, TelemetryPoint> latestPositions;
  final Set<String> hiddenPeers;
  final Function(String) onToggleVisibility;
  /// Optional scroll controller from a DraggableScrollableSheet.
  final ScrollController? scrollController;
  /// Optional header widget (e.g., drag handle for mobile sheet).
  final Widget? headerWidget;

  const PeerPanel({
    super.key,
    required this.streamer,
    required this.listener,
    required this.latestPositions,
    required this.hiddenPeers,
    required this.onToggleVisibility,
    this.scrollController,
    this.headerWidget,
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
    
    // Initiate consent handshake
    AtService.instance.sendConsentRequest(atSign);
    LocalDb.instance.updateConsentStatus(atSign, 'pending_outbound');
    
    _peerInputController.clear();
    setState(() {});
  }

  String _formatAge(DateTime timestamp) {
    final age = DateTime.now().toUtc().difference(timestamp);
    if (age.inSeconds < 60) return '${age.inSeconds}S AGO';
    if (age.inMinutes < 60) return '${age.inMinutes}M AGO';
    if (age.inHours < 24) return '${age.inHours}H AGO';
    return '${age.inDays}D AGO';
  }

  Widget _buildStatusControls(String peer, String status, bool outboundPermitted) {
    if (status == 'pending_inbound') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  AtService.instance.acceptConsentRequest(peer);
                  LocalDb.instance.updateConsentStatus(peer, 'approved');
                },
                style: AtNavTheme.primaryButton(),
                child: Text('ACCEPT', style: AtNavTheme.monoData(size: 10)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  AtService.instance.revokeConsent(peer);
                  LocalDb.instance.updateConsentStatus(peer, 'none');
                },
                style: AtNavTheme.primaryButton(isDestructive: true),
                child: Text('REJECT', style: AtNavTheme.monoData(size: 10)),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'pending_outbound') {
      return Row(
        children: [
          Text('WAITING...', style: AtNavTheme.monoLabel(size: 10, color: AtNavTheme.fgTertiary)),
          const Spacer(),
          InkWell(
            onTap: () {
              AtService.instance.revokeConsent(peer);
              LocalDb.instance.updateConsentStatus(peer, 'none');
            },
            child: Text('[CANCEL]', style: AtNavTheme.monoData(size: 10, color: AtNavTheme.accentOrange)),
          ),
        ],
      );
    } else if (status == 'approved') {
      return Row(
        children: [
          Text('ACTIVE', style: AtNavTheme.monoLabel(size: 10, color: AtNavTheme.terminalGreen)),
          const Spacer(),
          InkWell(
            onTap: () {
               LocalDb.instance.updateConsentStatus(peer, 'approved', outboundPermitted: !outboundPermitted);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: outboundPermitted ? AtNavTheme.terminalGreen.withValues(alpha: 0.1) : Colors.transparent,
                border: Border.all(color: outboundPermitted ? AtNavTheme.terminalGreen : AtNavTheme.fgTertiary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                outboundPermitted ? 'TX ON' : 'TX OFF',
                style: AtNavTheme.monoData(
                  size: 9,
                  color: outboundPermitted ? AtNavTheme.terminalGreen : AtNavTheme.fgTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              AtService.instance.revokeConsent(peer);
              LocalDb.instance.updateConsentStatus(peer, 'none');
              LocalDb.instance.deleteCoordinatesForPeer(peer);
            },
            child: Text('[REVOKE]', style: AtNavTheme.monoData(size: 10, color: AtNavTheme.accentOrange)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final atService = AtService.instance;

    return Container(
      decoration: AtNavTheme.panelDecoration(),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          if (widget.headerWidget != null) widget.headerWidget!,
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
                        height: 48,
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
                        height: 48,
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
                      height: 48,
                      width: 48,
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
                // Share duration dropdown removed
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
                  AtNavTheme.asciiFrame('CONSENT DIRECTORY'),
                  style: AtNavTheme.monoLabel(
                    size: 9,
                    color: AtNavTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ),

          // ── Peer List ──────────────────────────────────────────────
          StreamBuilder<dynamic>(
            stream: LocalDb.instance.watchConsents(),
              builder: (context, snapshot) {
                final consents = (snapshot.data as List<dynamic>?) ?? [];
                final validPeers = consents.where((c) => c.status != 'none').toList();
                
                if (!snapshot.hasData || validPeers.isEmpty) {
                  return Center(
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
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: validPeers.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: AtNavTheme.borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final peerConsent = validPeers[index];
                    final peer = peerConsent.peerAtsign as String;
                    final status = peerConsent.status as String;
                    final outboundPermitted = peerConsent.outboundPermitted as bool;
                    final position = widget.latestPositions[peer];
                    final hasData = position != null && status == 'approved';

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
                                  color: status == 'approved'
                                      ? AtNavTheme.terminalGreen
                                      : AtNavTheme.accentOrange,
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
                              if (status == 'approved')
                                InkWell(
                                  onTap: () => widget.onToggleVisibility(peer),
                                  child: Icon(
                                    widget.hiddenPeers.contains(peer)
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: widget.hiddenPeers.contains(peer)
                                        ? AtNavTheme.fgTertiary
                                        : AtNavTheme.terminalGreen,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildStatusControls(peer, status, outboundPermitted),
                          if (hasData) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'LAT ${position.latitude.toStringAsFixed(6)}',
                                    style: AtNavTheme.monoData(
                                      size: 10,
                                      color: AtNavTheme.fgSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'LNG ${position.longitude.toStringAsFixed(6)}',
                                    style: AtNavTheme.monoData(
                                      size: 10,
                                      color: AtNavTheme.fgSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
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
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
