import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/at_service.dart';
import 'theme.dart';

/// Full-screen, fully-responsive onboarding screen for atSign authentication.
///
/// Adapts padding, font sizes, icon sizes, and layout constraints to:
/// - Small phones  (< 360 px) — compact mode
/// - Standard phones (360–599 px) — standard mobile
/// - Tablets (600–799 px) — wider, form centred with max-width
/// - Desktop (≥ 800 px) — handled by MapScreen routing; not typically shown
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const OnboardingScreen({super.key, required this.onAuthenticated});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _atSignController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isLoading = false;
  String? _errorMessage;
  String _statusText = 'AWAITING CREDENTIALS';

  @override
  void dispose() {
    _atSignController.dispose();
    super.dispose();
  }

  Future<void> _pickAtKeysFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'SELECT .ATKEYS FILE',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _errorMessage = null;
            _statusText = 'FILE LOADED: ${file.name.toUpperCase()}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'FILE PICKER ERROR: ${e.toString().toUpperCase()}';
      });
    }
  }

  Future<void> _authenticate() async {
    final atSign = _atSignController.text.trim();
    if (atSign.isEmpty) {
      setState(() => _errorMessage = 'ATSIGN REQUIRED');
      return;
    }
    if (_selectedFilePath == null) {
      setState(() => _errorMessage = 'ATKEYS FILE REQUIRED');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'INITIATING PKAM HANDSHAKE...';
    });

    final atService = AtService.instance;
    final success = await atService.authenticate(
      atSign: atSign,
      atKeysFilePath: _selectedFilePath!,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _statusText = 'AUTHENTICATED: ${atService.currentAtSign}';
          _isLoading = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage =
              atService.authError?.toUpperCase() ?? 'AUTHENTICATION FAILED';
          _statusText = 'AUTH FAILURE';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Responsive tokens ──────────────────────────────────────────────────
    final double s = AtNavTheme.scaleOf(context);       // scale factor
    final double hp = AtNavTheme.hPad(context);          // horizontal padding
    final double ctrlH = AtNavTheme.controlHeight(context); // button/input height
    final bool wide = AtNavTheme.isWide(context);        // tablet+

    return Scaffold(
      backgroundColor: AtNavTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: hp,
                vertical: 14 * s,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AtNavTheme.accentOrange, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AtNavTheme.accentOrange,
                        size: 32 * s,
                      ),
                      SizedBox(width: 6 * s),
                      Text(
                        'AtNav',
                        style: AtNavTheme.macroHeader(34 * s),
                      ),
                    ],
                  ),
                  SizedBox(height: 5 * s),
                  Text(
                    'DECENTRALIZED LOCATION SHARING /// E2E ENCRYPTED',
                    style: AtNavTheme.monoLabel(
                      size: 8.5 * s,
                      color: AtNavTheme.fgTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Bar ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: hp, vertical: 8 * s),
              color: AtNavTheme.bgElevated,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    color: _isLoading
                        ? AtNavTheme.accentOrange
                        : AtNavTheme.fgTertiary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'STATUS: $_statusText',
                      style: AtNavTheme.monoData(
                        size: 10 * s,
                        color: AtNavTheme.fgSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Content — expands, optionally centred on tablet ───────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: hp,
                  vertical: 20 * s,
                ),
                child: Center(
                  child: ConstrainedBox(
                    // On tablets, cap the form width so it doesn't stretch
                    // awkwardly across the full screen.
                    constraints: BoxConstraints(
                      maxWidth: wide ? 480 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section label
                        Text(
                          AtNavTheme.asciiFrame('IDENTITY CREDENTIALS'),
                          style: AtNavTheme.monoLabel(
                            size: 9.5 * s,
                            color: AtNavTheme.accentOrange,
                          ),
                        ),
                        SizedBox(height: 14 * s),

                        // ── atSign input with centred @ ─────────────────
                        // IntrinsicHeight ensures the @ box is always
                        // pixel-identical in height to the TextField.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // @ prefix — vertically centred via Align
                              Container(
                                width: 48 * s,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AtNavTheme.bgElevated,
                                  border: Border.all(
                                    color: AtNavTheme.borderColor,
                                    width: 1,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  '@',
                                  style: AtNavTheme.monoData(
                                    size: 18 * s,
                                    color: AtNavTheme.accentOrange,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // Text input — takes remaining width
                              Expanded(
                                child: TextField(
                                  controller: _atSignController,
                                  style: AtNavTheme.monoData(size: 14 * s),
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    hintText: 'your_atsign',
                                    hintStyle: AtNavTheme.monoData(
                                      size: 13 * s,
                                      color: AtNavTheme.fgTertiary,
                                    ),
                                    filled: true,
                                    fillColor: AtNavTheme.bgPrimary,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12 * s,
                                      vertical: 0,
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(
                                        color: AtNavTheme.borderColor,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(
                                        color: AtNavTheme.accentOrange,
                                        width: 1,
                                      ),
                                    ),
                                    errorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(
                                        color: AtNavTheme.accentOrange,
                                        width: 2,
                                      ),
                                    ),
                                    focusedErrorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(
                                        color: AtNavTheme.accentOrange,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24 * s),

                        // Key file section label
                        Text(
                          AtNavTheme.asciiFrame('KEY FILE'),
                          style: AtNavTheme.monoLabel(
                            size: 9.5 * s,
                            color: AtNavTheme.accentOrange,
                          ),
                        ),
                        SizedBox(height: 8 * s),

                        // File picker drop zone
                        InkWell(
                          onTap: _isLoading ? null : _pickAtKeysFile,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 24 * s,
                              horizontal: 16 * s,
                            ),
                            decoration: BoxDecoration(
                              color: AtNavTheme.bgPrimary,
                              border: Border.all(
                                color: _selectedFilePath != null
                                    ? AtNavTheme.terminalGreen
                                    : AtNavTheme.borderColor,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedFilePath != null
                                      ? Icons.check_box_outlined
                                      : Icons.upload_file_outlined,
                                  color: _selectedFilePath != null
                                      ? AtNavTheme.terminalGreen
                                      : AtNavTheme.fgTertiary,
                                  size: 28 * s,
                                ),
                                SizedBox(height: 8 * s),
                                Text(
                                  _selectedFileName != null
                                      ? _selectedFileName!.toUpperCase()
                                      : 'SELECT .ATKEYS FILE',
                                  style: AtNavTheme.monoData(
                                    size: 11 * s,
                                    color: _selectedFilePath != null
                                        ? AtNavTheme.terminalGreen
                                        : AtNavTheme.fgSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4 * s),
                                Text(
                                  'CLICK TO BROWSE FILE SYSTEM',
                                  style: AtNavTheme.monoLabel(
                                    size: 8.5 * s,
                                    color: AtNavTheme.fgTertiary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20 * s),

                        // Error display
                        if (_errorMessage != null) ...[
                          Container(
                            padding: EdgeInsets.all(10 * s),
                            decoration: BoxDecoration(
                              color:
                                  AtNavTheme.accentOrange.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AtNavTheme.accentOrange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '!!! ',
                                  style: AtNavTheme.monoData(
                                    size: 11 * s,
                                    color: AtNavTheme.accentOrange,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AtNavTheme.monoData(
                                      size: 10 * s,
                                      color: AtNavTheme.accentOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14 * s),
                        ],

                        // Authenticate button — full width
                        SizedBox(
                          height: ctrlH,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _authenticate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AtNavTheme.accentOrange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AtNavTheme.bgElevated,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 14 * s,
                                        height: 14 * s,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10 * s),
                                      Text(
                                        'AUTHENTICATING...',
                                        style: AtNavTheme.monoData(
                                          size: 12 * s,
                                          weight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '>>> AUTHENTICATE',
                                    style: AtNavTheme.monoData(
                                      size: 12.5 * s,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: hp, vertical: 10 * s),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AtNavTheme.borderColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'ATSIGN PROTOCOL /// TLS ENCRYPTED',
                      style: AtNavTheme.monoLabel(
                        size: 7.5 * s,
                        color: AtNavTheme.fgTertiary,
                      ),
                    ),
                  ),
                  Text(
                    'REV 1.0 /// AtNav',
                    style: AtNavTheme.monoLabel(
                      size: 7.5 * s,
                      color: AtNavTheme.fgTertiary,
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
