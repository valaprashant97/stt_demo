import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpeechToTextApp());
}

class SpeechToTextApp extends StatelessWidget {
  const SpeechToTextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech to Text Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SpeechHomeScreen(),
    );
  }
}

class SpeechHomeScreen extends StatefulWidget {
  const SpeechHomeScreen({super.key});

  @override
  State<SpeechHomeScreen> createState() => _SpeechHomeScreenState();
}

class _SpeechHomeScreenState extends State<SpeechHomeScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();

  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  String _lastStatus = 'Not started';
  String _lastError = '';
  double _confidenceLevel = 0.0;
  double _soundLevel = 0.0;

  List<LocaleName> _localeNames = [];
  String _currentLocaleId = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Initialize SpeechToText plugin
  Future<void> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: _errorListener,
        onStatus: _statusListener,
      );

      if (available) {
        _localeNames = await _speechToText.locales();
        var systemLocale = await _speechToText.systemLocale();
        _currentLocaleId = systemLocale?.localeId ?? '';
      }

      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechEnabled = false;
          _lastError = e.toString();
        });
      }
    }
  }

  void _statusListener(String status) {
    if (mounted) {
      setState(() {
        _lastStatus = status;
        _isListening = _speechToText.isListening;
        if (_isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      });
    }
  }

  void _errorListener(SpeechRecognitionError error) {
    if (mounted) {
      setState(() {
        _lastError = '${error.errorMsg} - ${error.permanent}';
      });
    }
  }

  /// Start listening for speech
  void _startListening() async {
    _lastWords = '';
    _confidenceLevel = 0.0;
    _lastError = '';

    await _speechToText.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: _soundLevelListener,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : null,
      ),
    );

    if (mounted) {
      setState(() {
        _isListening = _speechToText.isListening;
        if (_isListening) {
          _pulseController.repeat(reverse: true);
        }
      });
    }
  }

  /// Stop listening for speech
  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _pulseController.stop();
        _pulseController.reset();
      });
    }
  }

  void _soundLevelListener(double level) {
    if (mounted) {
      setState(() {
        _soundLevel = level;
      });
    }
  }

  /// Callback when speech result is available
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _lastWords = result.recognizedWords;
        if (result.hasConfidenceRating && result.confidence > 0) {
          _confidenceLevel = result.confidence;
        }
      });
    }
  }

  void _copyToClipboard() {
    if (_lastWords.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _lastWords));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearText() {
    setState(() {
      _lastWords = '';
      _confidenceLevel = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech to Text Demo'),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-initialize Speech Engine',
            onPressed: _initSpeech,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              _buildStatusCard(colorScheme),
              const SizedBox(height: 16),

              // Language Selector
              if (_localeNames.isNotEmpty) _buildLanguageSelector(colorScheme),
              if (_localeNames.isNotEmpty) const SizedBox(height: 16),

              // Recognized Text Box
              Expanded(
                child: _buildTextCard(colorScheme),
              ),
              const SizedBox(height: 16),

              // Audio Level Bar
              if (_isListening) ...[
                _buildAudioVisualizer(colorScheme),
                const SizedBox(height: 16),
              ],

              // Microphone & Action Controls
              _buildControlPanel(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    Color statusColor;
    IconData statusIcon;

    if (!_speechEnabled) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else if (_isListening) {
      statusColor = Colors.green;
      statusIcon = Icons.mic_rounded;
    } else {
      statusColor = colorScheme.primary;
      statusIcon = Icons.mic_none_rounded;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _speechEnabled
                        ? (_isListening ? 'Listening...' : 'Ready to Listen')
                        : 'Speech STT Disabled / Not Permissioned',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Status: $_lastStatus',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_confidenceLevel > 0)
              Chip(
                backgroundColor: colorScheme.primaryContainer,
                label: Text(
                  '${(_confidenceLevel * 100).toStringAsFixed(0)}% conf.',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _currentLocaleId.isNotEmpty &&
                  _localeNames.any((element) => element.localeId == _currentLocaleId)
              ? _currentLocaleId
              : null,
          hint: const Text('Select Language'),
          icon: const Icon(Icons.language),
          onChanged: (String? selectedLocale) {
            if (selectedLocale != null) {
              setState(() {
                _currentLocaleId = selectedLocale;
              });
            }
          },
          items: _localeNames.map<DropdownMenuItem<String>>((LocaleName locale) {
            return DropdownMenuItem<String>(
              value: locale.localeId,
              child: Text(
                '${locale.name} (${locale.localeId})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _isListening
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: _isListening ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spoken Words:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    if (_lastWords.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy Text',
                        onPressed: _copyToClipboard,
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: 'Clear Text',
                        onPressed: _clearText,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _lastWords.isEmpty
                      ? (_speechEnabled
                          ? 'Tap the microphone button below and start speaking...'
                          : 'Speech recognition is not available or permission denied.')
                      : _lastWords,
                  style: TextStyle(
                    fontSize: _lastWords.isEmpty ? 16 : 20,
                    height: 1.4,
                    fontStyle:
                        _lastWords.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: _lastWords.isEmpty
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_lastError',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioVisualizer(ColorScheme colorScheme) {
    final double normalizedLevel =
        math.min(1.0, math.max(0.0, (_soundLevel + 10) / 20.0));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Listening Level',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(_soundLevel).toStringAsFixed(1)} dB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: normalizedLevel,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double scale = _isListening
                  ? 1.0 + (_pulseController.value * 0.15)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: FloatingActionButton.large(
                  onPressed: !_speechEnabled
                      ? _initSpeech
                      : (_isListening ? _stopListening : _startListening),
                  elevation: _isListening ? 8 : 4,
                  backgroundColor: _isListening
                      ? colorScheme.error
                      : colorScheme.primary,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 36,
                    color: _isListening
                        ? colorScheme.onError
                        : colorScheme.onPrimary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            !_speechEnabled
                ? 'Tap to initialize Speech Engine'
                : (_isListening ? 'Tap to Stop Listening' : 'Tap Microphone to Speak'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
