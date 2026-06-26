import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/at_service.dart';
import 'theme.dart';

/// Full-screen onboarding screen for atSign authentication.
///
/// Provides a `.atKeys` file picker with drag-and-drop zone,
/// atSign input field with a **centered** `@` prefix validation, and
/// connection status display with ASCII status codes.
///
/// Layout fills the entire viewport — no constrained center box.
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
      setState(() {
        _errorMessage = 'ATSIGN REQUIRED';
      });
      return;
    }

    if (_selectedFilePath == null) {
      setState(() {
        _errorMessage = 'ATKEYS FILE REQUIRED';
      });
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
        // Brief delay to show success status
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = atService.authError?.toUpperCase() ?? 'AUTHENTICATION FAILED';
          _statusText = 'AUTH FAILURE';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtNavTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AtNavTheme.accentOrange,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AtNav',
                    style: AtNavTheme.macroHeader(40),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DECENTRALIZED LOCATION SHARING /// E2E ENCRYPTED',
                    style: AtNavTheme.monoLabel(
                      size: 9,
                      color: AtNavTheme.fgTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
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
                  Text(
                    'STATUS: $_statusText',
                    style: AtNavTheme.monoData(
                      size: 10,
                      color: AtNavTheme.fgSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Content — expands to fill remaining space ───────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section label
                    Text(
                      AtNavTheme.asciiFrame('IDENTITY CREDENTIALS'),
                      style: AtNavTheme.monoLabel(
                        size: 10,
                        color: AtNavTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── atSign input with centred @ ──────────────────────
                    // We need the @ glyph to be vertically centred inside
                    // the input row.  We achieve this by placing it inside
                    // an IntrinsicHeight Row so it can align Alignment.center
                    // regardless of the input's dynamic height.
                    SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // @ prefix box — same height as the text field
                          Container(
                            width: 52,
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
                                size: 20,
                                color: AtNavTheme.accentOrange,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Text input — takes remaining width
                          Expanded(
                            child: TextField(
                              controller: _atSignController,
                              style: AtNavTheme.monoData(size: 14),
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: 'your_atsign',
                                hintStyle: AtNavTheme.monoData(
                                  size: 14,
                                  color: AtNavTheme.fgTertiary,
                                ),
                                filled: true,
                                fillColor: AtNavTheme.bgPrimary,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
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
                    const SizedBox(height: 28),

                    // .atKeys file picker section label
                    Text(
                      AtNavTheme.asciiFrame('KEY FILE'),
                      style: AtNavTheme.monoLabel(
                        size: 10,
                        color: AtNavTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // File picker drop zone
                    InkWell(
                      onTap: _isLoading ? null : _pickAtKeysFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 20,
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
                              size: 32,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedFileName != null
                                  ? _selectedFileName!.toUpperCase()
                                  : 'SELECT .ATKEYS FILE',
                              style: AtNavTheme.monoData(
                                size: 12,
                                color: _selectedFilePath != null
                                    ? AtNavTheme.terminalGreen
                                    : AtNavTheme.fgSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'CLICK TO BROWSE FILE SYSTEM',
                              style: AtNavTheme.monoLabel(
                                size: 9,
                                color: AtNavTheme.fgTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error display
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AtNavTheme.accentOrange.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AtNavTheme.accentOrange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '!!! ',
                              style: AtNavTheme.monoData(
                                size: 12,
                                color: AtNavTheme.accentOrange,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AtNavTheme.monoData(
                                  size: 10,
                                  color: AtNavTheme.accentOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Authenticate button — full width
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        style: AtNavTheme.primaryButton(isDestructive: true).copyWith(
                          backgroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.disabled)) {
                              return AtNavTheme.bgElevated;
                            }
                            if (states.contains(WidgetState.pressed)) {
                              return const Color(0xFFE04900);
                            }
                            return AtNavTheme.accentOrange;
                          }),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'AUTHENTICATING...',
                                    style: AtNavTheme.monoData(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '>>> AUTHENTICATE',
                                style: AtNavTheme.monoData(
                                  size: 13,
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

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AtNavTheme.borderColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ATSIGN PROTOCOL /// TLS ENCRYPTED',
                    style: AtNavTheme.monoLabel(
                      size: 8,
                      color: AtNavTheme.fgTertiary,
                    ),
                  ),
                  Text(
                    'REV 1.0 /// AtNav',
                    style: AtNavTheme.monoLabel(
                      size: 8,
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
