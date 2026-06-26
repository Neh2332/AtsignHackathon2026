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
import 'theme.dart';

/// Main map screen with adaptive layout.
///
/// Layout adapts based on [AppConstants.desktopBreakpoint] (800px):
///
/// **Desktop (≥ 800px)**:
/// - Top status bar with system info
/// - Horizontal split-pane: 30% PeerPanel sidebar | 70% FlutterMap
/// - Bottom real-time telemetry ticker
/// - Floating map overlay (peer coords, top-right)
///
/// **Mobile (< 800px)**:
/// - AppBar with connection status and logout button
/// - Full-screen FlutterMap
/// - DraggableScrollableSheet for peer management (slides up from bottom)
/// - Telemetry ticker strip above the sheet
class MapScreen extends StatefulWidget {
  /// Called when the user signs out so the root widget can navigate
  /// back to the onboarding screen.
  final VoidCallback? onSignOut;

  const MapScreen({super.key, this.onSignOut});

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
  final Set<String> _hiddenPeers = {};
  StreamSubscription<Map<String, TelemetryPoint>>? _positionSubscription;
  StreamSubscription<TelemetryPoint>? _pointSubscription;

  // Pulsing animation for active pins
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Sheet controller — only used on mobile layout
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  void _togglePeerVisibility(String atSign) {
    setState(() {
      if (_hiddenPeers.contains(atSign)) {
        _hiddenPeers.remove(atSign);
      } else {
        _hiddenPeers.add(atSign);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _localDb = LocalDb.instance;
    _streamer = TelemetryStreamer(AtService.instance, _localDb);
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
    _sheetController.dispose();
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

  // ── Root Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isDesktop = width >= AppConstants.desktopBreakpoint;

    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }

  // ── Desktop Layout ─────────────────────────────────────────────────────────

  /// Desktop layout: top bar + horizontal split-pane + bottom ticker.
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AtNavTheme.bgPrimary,
      body: Column(
        children: [
          // ── Top Status Bar ───────────────────────────────────────────
          _buildTopBar(),

          // ── Main Content (Split Pane) ────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Panel: Peer Management (30%)
                SizedBox(
                  width: MediaQuery.sizeOf(context).width *
                      AppConstants.sidebarWidthRatio,
                  child: PeerPanel(
                    streamer: _streamer,
                    listener: _listener,
                    latestPositions: _latestPositions,
                    hiddenPeers: _hiddenPeers,
                    onToggleVisibility: _togglePeerVisibility,
                  ),
                ),

                // Vertical Divider
                Container(width: 1, color: AtNavTheme.borderColor),

                // Right Panel: Map (70%)
                Expanded(
                  child: Stack(
                    children: [
                      _buildMap(),
                      _buildMapOverlay(),
                      _buildZoomControls(isMobile: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top status bar shown on desktop only.
  Widget _buildTopBar() {
    final isOnline = AtService.instance.isAuthenticated;
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
          const Icon(
            Icons.location_on,
            color: AtNavTheme.accentOrange,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'AtNav',
            style: AtNavTheme.macroHeader(13),
          ),
          const SizedBox(width: 12),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnline
                  ? AtNavTheme.terminalGreen
                  : AtNavTheme.accentOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: AtNavTheme.monoData(
              size: 9,
              color:
                  isOnline ? AtNavTheme.terminalGreen : AtNavTheme.accentOrange,
            ),
          ),
          const Spacer(),
          Text(
            'PEERS: ${_latestPositions.length}',
            style: AtNavTheme.monoData(size: 9, color: AtNavTheme.fgSecondary),
          ),
          const SizedBox(width: 16),
          Text(
            'E2E: AES-256',
            style: AtNavTheme.monoData(size: 9, color: AtNavTheme.fgTertiary),
          ),
        ],
      ),
    );
  }

  // ── Mobile Layout ──────────────────────────────────────────────────────────

  /// Mobile layout: AppBar + full-screen map + draggable bottom sheet.
  Widget _buildMobileLayout() {
    // Adapt sheet snap sizes to screen height so the panel feels natural
    // on compact phones (e.g. SE) and tall phones (e.g. Pro Max) alike.
    final double screenH = MediaQuery.sizeOf(context).height;
    final double initSnap  = screenH < 700 ? 0.10 : 0.12;
    final double midSnap   = screenH < 700 ? 0.40 : 0.45;
    final double maxSnap   = screenH < 700 ? 0.70 : 0.75;

    return Scaffold(
      backgroundColor: AtNavTheme.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: _buildMobileAppBar(),
      ),
      body: Stack(
        children: [
          // ── Full-screen Map ───────────────────────────────────────
          _buildMap(),

          // ── Map Overlay (Peer coords, top-right) ──────────────────
          _buildMapOverlay(useSafeArea: true),

          // ── Zoom Controls ───────────────────────────────────────
          _buildZoomControls(isMobile: true, useSafeArea: true),

          // ── Peer Management Bottom Sheet ───────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: initSnap,
            minChildSize: initSnap * 0.65,
            maxChildSize: maxSnap,
            snap: true,
            snapSizes: [initSnap, midSnap, maxSnap],
            builder: (context, scrollController) {
              return _buildPeerSheet(scrollController);
            },
          ),
        ],
      ),
    );
  }

  /// Mobile AppBar with AtNav branding, connection status, and logout.
  Widget _buildMobileAppBar() {
    final isOnline = AtService.instance.isAuthenticated;
    // Scale title font with screen width
    final double s = AtNavTheme.scaleOf(context);
    return AppBar(
      backgroundColor: AtNavTheme.bgPrimary,
      elevation: 0,
      titleSpacing: 14,
      title: Row(
        children: [
          Icon(
            Icons.location_on,
            color: AtNavTheme.accentOrange,
            size: 18 * s,
          ),
          SizedBox(width: 5 * s),
          Text(
            'AtNav',
            style: AtNavTheme.macroHeader(18 * s),
          ),
          SizedBox(width: 7 * s),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnline
                  ? AtNavTheme.terminalGreen
                  : AtNavTheme.accentOrange,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: AtNavTheme.monoData(
                  size: 9,
                  color: isOnline
                      ? AtNavTheme.terminalGreen
                      : AtNavTheme.accentOrange,
                ),
              ),
              Text(
                'PEERS: ${_latestPositions.length}',
                style: AtNavTheme.monoData(
                  size: 9,
                  color: AtNavTheme.fgTertiary,
                ),
              ),
            ],
          ),
        ),
        // ── Logout button ───────────────────────────────────────────────
        IconButton(
          tooltip: 'Log Out',
          icon: const Icon(
            Icons.logout,
            color: AtNavTheme.accentOrange,
            size: 22,
          ),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AtNavTheme.bgPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AtNavTheme.borderColor),
                ),
                title: Text(
                  'LOG OUT',
                  style: AtNavTheme.macroHeader(16),
                ),
                content: Text(
                  'This will clear your session and return to the login screen.',
                  style: AtNavTheme.monoData(size: 13, color: AtNavTheme.fgSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'CANCEL',
                      style: AtNavTheme.monoData(size: 12, color: AtNavTheme.fgSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AtNavTheme.accentOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'LOG OUT',
                      style: AtNavTheme.monoData(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await AtService.instance.signOut();
              widget.onSignOut?.call();
            }
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AtNavTheme.borderColor),
      ),
    );
  }

  /// Mobile peer sheet that slides up from the bottom.
  Widget _buildPeerSheet(ScrollController scrollController) {
    return SafeArea(
      bottom: true,
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AtNavTheme.bgPrimary,
          border: const Border(
            top: BorderSide(color: AtNavTheme.accentOrange, width: 2),
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
      child: PeerPanel(
        streamer: _streamer,
        listener: _listener,
        latestPositions: _latestPositions,
        hiddenPeers: _hiddenPeers,
        onToggleVisibility: _togglePeerVisibility,
        scrollController: scrollController,
        headerWidget: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AtNavTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────────

  /// Builds the flutter_map widget with CartoDB light tiles.
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
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
  List<Polyline> _buildTrailPolylines() {
    final List<Polyline> polylines = [];

    for (final entry in _trails.entries) {
      if (_hiddenPeers.contains(entry.key)) continue;
      final trail = entry.value;
      if (trail.length < 2) continue;

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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AtNavTheme.bgElevated.withValues(alpha: 0.8),
                        border:
                            Border.all(color: AtNavTheme.terminalGreen, width: 1),
                      ),
                      child: Text(
                        'SELF',
                        style: AtNavTheme.monoData(
                            size: 10, color: AtNavTheme.terminalGreen),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 8,
                      color: AtNavTheme.terminalGreen,
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
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
            ],
          ),
        ),
      );
    }

    for (final entry in _latestPositions.entries) {
      if (_hiddenPeers.contains(entry.key)) continue;
      final position = entry.value;

      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AtNavTheme.bgElevated.withValues(alpha: 0.8),
                        border: Border.all(
                            color: AtNavTheme.accentOrange, width: 1),
                      ),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AtNavTheme.monoData(
                            size: 10, color: AtNavTheme.accentOrange),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 8,
                      color: AtNavTheme.accentOrange,
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
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
            ],
          ),
        ),
      );
    }

    return markers;
  }

  /// Map overlay with active peer coordinate readouts (top-right corner).
  Widget _buildMapOverlay({bool useSafeArea = false}) {
    if (_latestPositions.isEmpty) return const SizedBox.shrink();

    Widget content = Container(
      padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AtNavTheme.bgPrimary.withValues(alpha: 0.9),
          border: Border.all(color: AtNavTheme.borderColor, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LIVE SIGNALS',
              style: AtNavTheme.monoLabel(
                size: 8,
                color: AtNavTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 6),
            ..._latestPositions.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
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
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return Positioned(
      top: 12,
      right: 12,
      child: content,
    );
  }

  // ── Zoom Controls ────────────────────────────────────────────────────────
  
  Widget _buildZoomControls({required bool isMobile, bool useSafeArea = false}) {
    // Button size scales with screen width
    final double btnSize = AtNavTheme.controlHeight(context) - 4;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(Icons.add, btnSize, () {
          final z = _mapController.camera.zoom;
          _mapController.move(_mapController.camera.center, z + 1);
        }),
        SizedBox(height: 10),
        _zoomButton(Icons.remove, btnSize, () {
          final z = _mapController.camera.zoom;
          _mapController.move(_mapController.camera.center, z - 1);
        }),
      ],
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    // Zoom controls sit at the very top-right, directly beneath the
    // navigation header on both mobile and desktop.
    return Positioned(
      right: 12,
      top: 12,
      child: content,
    );
  }

  Widget _zoomButton(IconData icon, double size, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AtNavTheme.bgSurface.withValues(alpha: 0.95),
          border: Border.all(color: AtNavTheme.borderColor),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: AtNavTheme.fgPrimary, size: size * 0.4),
      ),
    );
  }
}
