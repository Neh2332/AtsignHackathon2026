import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/telemetry_point.dart';
import '../subscriber/telemetry_listener.dart';
import 'theme.dart';

/// Bottom status bar with scrolling real-time telemetry data feed.
///
/// Displays incoming coordinate data in monospace format, simulating
/// a terminal data stream. Each new telemetry point is prepended to
/// the feed with a timestamp and formatted coordinates.
///
/// Styling: Monospace, uppercase, tight tracking, with Aviation Red
/// accents for peer identifiers.
class TelemetryTicker extends StatefulWidget {
  final TelemetryListener listener;

  const TelemetryTicker({super.key, required this.listener});

  @override
  State<TelemetryTicker> createState() => _TelemetryTickerState();
}

class _TelemetryTickerState extends State<TelemetryTicker> {
  final List<_TickerEntry> _entries = [];
  final int _maxEntries = 50;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<TelemetryPoint>? _subscription;
  final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');

  @override
  void initState() {
    super.initState();
    _subscription = widget.listener.pointStream.listen(_onNewPoint);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewPoint(TelemetryPoint point) {
    setState(() {
      _entries.insert(
        0,
        _TickerEntry(
          timestamp: DateTime.now(),
          peerAtSign: point.peerAtSign,
          latitude: point.latitude,
          longitude: point.longitude,
          accuracy: point.accuracy,
        ),
      );

      // Trim old entries
      if (_entries.length > _maxEntries) {
        _entries.removeRange(_maxEntries, _entries.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AtNavTheme.bgPrimary,
        border: Border(
          top: BorderSide(color: AtNavTheme.accentOrange, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Ticker Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: AtNavTheme.bgElevated,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '< COORDINATE STREAM >',
                  style: AtNavTheme.monoLabel(
                    size: 9,
                    color: AtNavTheme.accentOrange,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.listener.isListening
                            ? AtNavTheme.terminalGreen
                            : AtNavTheme.fgTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RX ${widget.listener.receivedCount}',
                      style: AtNavTheme.monoData(
                        size: 9,
                        color: AtNavTheme.fgTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Ticker Feed ────────────────────────────────────────────
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      '--- AWAITING INBOUND TELEMETRY ---',
                      style: AtNavTheme.monoData(
                        size: 10,
                        color: AtNavTheme.fgTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    itemCount: _entries.length,
                    itemExtent: 16,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Row(
                        children: [
                          Text(
                            _timeFormat.format(entry.timestamp.toLocal()),
                            style: AtNavTheme.monoData(
                              size: 9,
                              color: AtNavTheme.fgTertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '|',
                            style: AtNavTheme.monoData(
                              size: 9,
                              color: AtNavTheme.borderColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.peerAtSign.toUpperCase(),
                            style: AtNavTheme.monoData(
                              size: 9,
                              color: AtNavTheme.accentOrange,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'LAT ${entry.latitude.toStringAsFixed(6)}',
                            style: AtNavTheme.monoData(
                              size: 9,
                              color: AtNavTheme.fgSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'LNG ${entry.longitude.toStringAsFixed(6)}',
                            style: AtNavTheme.monoData(
                              size: 9,
                              color: AtNavTheme.fgSecondary,
                            ),
                          ),
                          if (entry.accuracy != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              'ACC ${entry.accuracy!.toStringAsFixed(1)}M',
                              style: AtNavTheme.monoData(
                                size: 9,
                                color: AtNavTheme.fgTertiary,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Internal model for ticker feed entries.
class _TickerEntry {
  final DateTime timestamp;
  final String peerAtSign;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const _TickerEntry({
    required this.timestamp,
    required this.peerAtSign,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}
