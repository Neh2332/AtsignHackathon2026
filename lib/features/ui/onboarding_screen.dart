import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/at_service.dart';
import 'theme.dart';

/// Industrial Brutalist onboarding screen for atSign authentication.
///
/// Provides a `.atKeys` file picker with drag-and-drop zone,
/// atSign input field with `@` prefix validation, and connection
/// status display with ASCII status codes.
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
      body: Center(
        child: Container(
          width: 520,
          decoration: AtNavTheme.panelDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
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
                      style: AtNavTheme.macroHeader(36),
                    ),
                    const SizedBox(height: 4),
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

              // ── Status Bar ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
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

              // ── Form Content ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
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

                    // atSign input
                    TextField(
                      controller: _atSignController,
                      style: AtNavTheme.monoData(size: 14),
                      decoration: AtNavTheme.inputDecoration(
                        label: 'ATSIGN',
                        hint: '@your_atsign',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 4),
                          child: Text(
                            '@',
                            style: AtNavTheme.monoData(
                              size: 16,
                              color: AtNavTheme.accentOrange,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // .atKeys file picker
                    Text(
                      AtNavTheme.asciiFrame('KEY FILE'),
                      style: AtNavTheme.monoLabel(
                        size: 10,
                        color: AtNavTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      onTap: _isLoading ? null : _pickAtKeysFile,
                      child: Container(
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            Icon(
                              _selectedFilePath != null
                                  ? Icons.check_box_outlined
                                  : Icons.upload_file_outlined,
                              color: _selectedFilePath != null
                                  ? AtNavTheme.terminalGreen
                                  : AtNavTheme.fgTertiary,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName != null
                                  ? _selectedFileName!.toUpperCase()
                                  : 'SELECT .ATKEYS FILE',
                              style: AtNavTheme.monoData(
                                size: 11,
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
                    const SizedBox(height: 20),

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

                    // Authenticate button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        style: AtNavTheme.primaryButton(),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AtNavTheme.accentOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'AUTHENTICATING...',
                                    style: AtNavTheme.monoData(
                                      size: 12,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '>>> AUTHENTICATE',
                                style: AtNavTheme.monoData(
                                  size: 12,
                                  weight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
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
      ),
    );
  }
}
