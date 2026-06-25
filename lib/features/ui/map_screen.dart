import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/at_service.dart';
import '../../core/constants.dart';
import '../../models/telemetry_point.dart';
import '../publisher/telemetry_streamer.dart';
import '../subscriber/telemetry_listener.dart';
import '../storage/local_db.dart';
import 'peer_panel.dart';
import 'telemetry_ticker.dart';
import 'theme.dart';

/// Main map screen with split-pane desktop layout.
///
/// Layout:
/// - Left panel (30%): Peer management sidebar
/// - Right panel (70%): Full-bleed flutter_map with OSM dark tiles
/// - Bottom bar: Real-time telemetry data ticker
///
/// Design: Tactical Telemetry industrial brutalist with:
/// - Dark-mode OSM tile layer
/// - Animated peer pins with pulsing red halos
/// - Polyline trails with decreasing opacity
/// - CRT scanline overlay
/// - ASCII-framed status indicators
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final TelemetryStreamer _streamer;
  late final TelemetryListener _listener;
  late final LocalDb _localDb;
  late final MapController _mapController;

  Map<String, TelemetryPoint> _latestPositions = {};
  final Map<String, List<TelemetryPoint>> _trails = {};
  StreamSubscription<Map<String, TelemetryPoint>>? _positionSubscription;
  StreamSubscription<TelemetryPoint>? _pointSubscription;

  // Pulsing animation for active pins
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _localDb = LocalDb.instance;
    _streamer = TelemetryStreamer(AtService.instance);
    _listener = TelemetryListener(AtService.instance, _localDb);
    _mapController = MapController();

    // Start the eviction loop
    _localDb.startEvictionLoop();

    // Start listening for inbound telemetry
    _listener.startListening();

    // Subscribe to latest positions from the database
    _positionSubscription = _localDb.watchLatestByPeer().listen((positions) {
      if (mounted) {
        setState(() {
          _latestPositions = positions;
        });
        // Load trails for each peer
        for (final peer in positions.keys) {
          _loadTrail(peer);
        }
      }
    });

    // Subscribe to new points for real-time trail updates
    _pointSubscription = _listener.pointStream.listen((point) {
      _loadTrail(point.peerAtSign);
    });

    // Pulsing animation for active peer pins
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to streamer and listener changes to rebuild UI
    _streamer.addListener(_onServiceUpdate);
    _listener.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTrail(String peerAtSign) async {
    final trail = await _localDb.getTrail(
      peerAtSign,
      limit: AppConstants.maxTrailPoints,
    );
    if (mounted) {
      setState(() {
        _trails[peerAtSign] = trail;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionSubscription?.cancel();
    _pointSubscription?.cancel();
    _streamer.removeListener(_onServiceUpdate);
    _listener.removeListener(_onServiceUpdate);
    _streamer.dispose();
    _listener.dispose();
    _localDb.stopEvictionLoop();
    super.dispose();
  }

  /// Centers the map on a specific peer's latest position.
  void _centerOnPeer(String peerAtSign) {
    final position = _latestPositions[peerAtSign];
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        AppConstants.defaultMapZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtNavTheme.bgPrimary,
      body: Column(
        children: [
          // ── Top Status Bar ───────────────────────────────────────────
          _buildTopBar(),

          // ── Main Content (Split Pane) ────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Left Panel: Peer Management (30%)
                SizedBox(
                  width: MediaQuery.of(context).size.width *
                      AppConstants.sidebarWidthRatio,
                  child: PeerPanel(
                    streamer: _streamer,
                    listener: _listener,
                    latestPositions: _latestPositions,
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  color: AtNavTheme.borderColor,
                ),

                // Right Panel: Map (70%)
                Expanded(
                  child: Stack(
                    children: [
                      _buildMap(),
                      AtNavTheme.scanlineOverlay(),
                      _buildMapOverlay(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Ticker ────────────────────────────────────────────
          TelemetryTicker(listener: _listener),
        ],
      ),
    );
  }

  /// Top navigation bar with system status.
  Widget _buildTopBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AtNavTheme.bgElevated,
        border: Border(
          bottom: BorderSide(color: AtNavTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'AtNav /// TACTICAL LOCATION SYSTEM',
            style: AtNavTheme.monoLabel(
              size: 9,
              color: AtNavTheme.fgTertiary,
            ),
          ),
          const Spacer(),
          Text(
            'PEERS: ${_latestPositions.length}',
            style: AtNavTheme.monoData(
              size: 9,
              color: AtNavTheme.fgSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'E2E: AES-256',
            style: AtNavTheme.monoData(
              size: 9,
              color: AtNavTheme.fgTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AtService.instance.isAuthenticated
                      ? AtNavTheme.terminalGreen
                      : AtNavTheme.accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AtService.instance.isAuthenticated ? 'ONLINE' : 'OFFLINE',
                style: AtNavTheme.monoData(
                  size: 9,
                  color: AtService.instance.isAuthenticated
                      ? AtNavTheme.terminalGreen
                      : AtNavTheme.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the flutter_map widget with dark OSM tiles.
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _latestPositions.isNotEmpty
            ? LatLng(
                _latestPositions.values.first.latitude,
                _latestPositions.values.first.longitude,
              )
            : const LatLng(37.7749, -122.4194), // Default: San Francisco
        initialZoom: AppConstants.defaultMapZoom,
        backgroundColor: AtNavTheme.bgPrimary,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.atnav.app',
          maxZoom: 19,
          retinaMode: RetinaMode.isHighDensity(context),
        ),

        // Polyline trails for each peer
        PolylineLayer(
          polylines: _buildTrailPolylines(),
        ),

        // Peer markers
        MarkerLayer(
          markers: _buildPeerMarkers(),
        ),
      ],
    );
  }

  /// Builds polyline trails for all tracked peers.
  ///
  /// Each trail is rendered as a semi-transparent red path.
  /// Older segments have lower opacity to create a fade-out effect.
  List<Polyline> _buildTrailPolylines() {
    final List<Polyline> polylines = [];

    for (final entry in _trails.entries) {
      final trail = entry.value;
      if (trail.length < 2) continue;

      // Convert trail points to LatLng list (reversed to oldest→newest)
      final points = trail.reversed
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      polylines.add(
        Polyline(
          points: points,
          color: AtNavTheme.accentOrange.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      );
    }

    return polylines;
  }

  /// Builds animated marker widgets for all tracked peers.
  List<Marker> _buildPeerMarkers() {
    final List<Marker> markers = [];

    // Add self marker if streaming
    if (_streamer.isStreaming && _streamer.lastPosition != null) {
      final position = _streamer.lastPosition!;
      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing halo (Green for self)
                  Container(
                    width: 32 * _pulseAnimation.value,
                    height: 32 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      color: AtNavTheme.terminalGreen.withValues(
                        alpha: 0.3 * (1 - _pulseAnimation.value),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Outer ring
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AtNavTheme.terminalGreen,
                        width: 2,
                      ),
                    ),
                  ),
                  // Inner dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AtNavTheme.terminalGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    for (final entry in _latestPositions.entries) {
      final position = entry.value;

      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing halo
                  Container(
                    width: 32 * _pulseAnimation.value,
                    height: 32 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      color: AtNavTheme.accentOrange.withValues(
                        alpha: 0.3 * (1 - _pulseAnimation.value),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Outer ring
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AtNavTheme.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                  // Inner dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AtNavTheme.accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  /// Builds the map overlay with coordinate readouts and crosshairs.
  Widget _buildMapOverlay() {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AtNavTheme.bgPrimary.withValues(alpha: 0.85),
          border: Border.all(color: AtNavTheme.borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AtNavTheme.asciiFrame('MAP CONTROL'),
              style: AtNavTheme.monoLabel(
                size: 8,
                color: AtNavTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 6),
            if (_latestPositions.isEmpty)
              Text(
                'NO ACTIVE SIGNALS',
                style: AtNavTheme.monoData(
                  size: 9,
                  color: AtNavTheme.fgTertiary,
                ),
              )
            else
              ..._latestPositions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => _centerOnPeer(entry.key),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          color: AtNavTheme.accentOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.key.toUpperCase(),
                          style: AtNavTheme.monoData(
                            size: 9,
                            color: AtNavTheme.accentOrange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.latitude.toStringAsFixed(4)}, '
                          '${entry.value.longitude.toStringAsFixed(4)}',
                          style: AtNavTheme.monoData(
                            size: 9,
                            color: AtNavTheme.fgSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
