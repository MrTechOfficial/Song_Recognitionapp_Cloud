import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hands-Free Song Identifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioRecorderScreen(),
    );
  }
}

enum EnvironmentMode {
  quiet(label: 'A quiet room', duration: 6, icon: Icons.king_bed),
  loud(
      label: 'A loud room with background noise',
      duration: 8,
      icon: Icons.volume_up),
  skiing(label: 'Skiing', duration: 12, icon: Icons.downhill_skiing);

  final String label;
  final int duration;
  final IconData icon;

  const EnvironmentMode({
    required this.label,
    required this.duration,
    required this.icon,
  });
}

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _siriChannel =
      MethodChannel('com.handsfreefinder/siri');

  late final AudioPlayer _dingPlayer;
  late final AudioPlayer _errorPlayer;
  late final AudioPlayer _silencePlayer;
  late final AudioRecorder _audioRecorder;
  AirPodsAudioHandler? _airPodsHandler;

  bool _isRecording = false;
  bool _isLoading = false;

  EnvironmentMode _selectedMode = EnvironmentMode.skiing;
  int _secondsRemaining = 12;
  Timer? _autoStopTimer;
  Timer? _countdownTimer;

  // App Settings / Preferences
  String _preferredMusicApp = 'spotify'; // 'spotify' or 'apple_music'
  String _selectedLanguage = 'en'; // Language code (e.g., 'en', 'es', 'fr')

  final Map<String, String> _languages = {
    'en': '🇺🇸 English',
    'es': '🇪🇸 Español',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'ja': '🇯🇵 日本語',
  };

  String _statusText =
      'Select your environment and tap the mic or squeeze AirPods stem!';
  String? _songTitle;
  String? _artist;
  String? _spotifyUrl;
  String? _appleMusicUrl;

  final String _backendUrl =
      'https://song-recognitionapp-cloud.onrender.com/recognize';

  final String _dingUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
  final String _errorSoundUrl =
      'https://assets.mixkit.co/active_storage/sfx/2873/2873-preview.mp3';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    _dingPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    _silencePlayer = AudioPlayer();

    _loadSavedMode();
    _loadPreferences();
    _initSilencePlayer();

    if (!kIsWeb) {
      _initAirPodsListener();
      _initSiriListener();
    }
  }

  // Load User Preferences (Language & Default Music Player)
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApp = prefs.getString('preferred_music_app');
    final savedLang = prefs.getString('preferred_language');

    setState(() {
      _preferredMusicApp = savedApp ?? 'spotify';
      _selectedLanguage = savedLang ?? 'en';
    });

    // If first launch, prompt preferences modal
    if (savedApp == null || savedLang == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPreferencesDialog();
      });
    }
  }

  Future<void> _savePreferences(String musicApp, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_music_app', musicApp);
    await prefs.setString('preferred_language', lang);
    setState(() {
      _preferredMusicApp = musicApp;
      _selectedLanguage = lang;
    });
  }

  void _showPreferencesDialog() {
    String tempApp = _preferredMusicApp;
    String tempLang = _selectedLanguage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('App Preferences'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferred Music App',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Spotify'),
                    value: 'spotify',
                    groupValue: tempApp,
                    onChanged: (val) {
                      setModalState(() => tempApp = val!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Apple Music'),
                    value: 'apple_music',
                    groupValue: tempApp,
                    onChanged: (val) {
                      setModalState(() => tempApp = val!);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Preferred Language',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempLang,
                    items: _languages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => tempLang = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _savePreferences(tempApp, tempLang);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _initSiriListener() {
    _siriChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSiriTrigger') {
        _triggerAutoRecordingFromSiri();
      }
    });

    _siriChannel.invokeMethod<String>('getInitialUrl').then((url) {
      if (url != null && url.isNotEmpty) {
        _triggerAutoRecordingFromSiri();
      }
    });
  }

  void _triggerAutoRecordingFromSiri() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isRecording && !_isLoading && mounted) {
        _startRecording(playDing: true);
      }
    });
  }

  Future<void> _initSilencePlayer() async {
    try {
      await _silencePlayer.setReleaseMode(ReleaseMode.loop);
      await _silencePlayer.play(AssetSource('silence.mp3'));
    } catch (e) {
      debugPrint('Error starting local silence background audio: $e');
    }
  }

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('selected_environment_mode');
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < EnvironmentMode.values.length) {
      setState(() {
        _selectedMode = EnvironmentMode.values[savedIndex];
        _secondsRemaining = _selectedMode.duration;
      });
    }
  }

  Future<void> _saveMode(EnvironmentMode mode) async {
    setState(() {
      _selectedMode = mode;
      _secondsRemaining = mode.duration;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_environment_mode', mode.index);
  }

  Future<void> _saveToHistory(String songEntry) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('song_history') ?? [];
    history.insert(0, songEntry);
    await prefs.setStringList('song_history', history);
  }

  Future<void> _initAirPodsListener() async {
    try {
      _airPodsHandler = await AudioService.init(
        builder: () => AirPodsAudioHandler(
          onMediaButtonTriggered: () {
            triggerAirPodsSqueeze();
          },
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.example.song_recognition.channel.audio',
          androidNotificationChannelName: 'AirPods Song Finder',
          androidNotificationOngoing: false,
        ),
      );
    } catch (e) {
      debugPrint('AirPods listener setup notice: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    _dingPlayer.dispose();
    _errorPlayer.dispose();
    _silencePlayer.dispose();
    super.dispose();
  }

  Future<void> _playDingCue() async {
    try {
      await _dingPlayer.play(UrlSource(_dingUrl));
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error playing chime: $e');
    }
  }

  Future<void> _playErrorCue() async {
    try {
      await _errorPlayer.play(UrlSource(_errorSoundUrl));
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Error playing failure sound: $e');
    }
  }

  void triggerAirPodsSqueeze() {
    if (!_isRecording && !_isLoading) {
      _startRecording(playDing: false);
    } else if (_isRecording) {
      _stopAndSendRecording();
    }
  }

  Future<void> _startRecording({bool playDing = true}) async {
    if (_isRecording || _isLoading) return;

    try {
      if (kIsWeb || await Permission.microphone.request().isGranted) {
        await _silencePlayer.pause();

        if (playDing) {
          await _playDingCue();
          await Future.delayed(const Duration(milliseconds: 500));
        }

        String filePath = '';

        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          filePath = '${directory.path}/recording.wav';
        }

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        final int duration = _selectedMode.duration;

        setState(() {
          _isRecording = true;
          _secondsRemaining = duration;
          _statusText = 'Listening... (${_secondsRemaining}s remaining)';
          _songTitle = null;
          _artist = null;
          _spotifyUrl = null;
          _appleMusicUrl = null;
        });

        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() {
            if (_secondsRemaining > 1) {
              _secondsRemaining--;
              _statusText = 'Listening... (${_secondsRemaining}s remaining)';
            } else {
              _countdownTimer?.cancel();
            }
          });
        });

        _autoStopTimer?.cancel();
        _autoStopTimer = Timer(Duration(seconds: duration), () {
          _stopAndSendRecording();
        });
      } else {
        setState(() {
          _statusText = 'Microphone permission denied.';
        });
        _playErrorCue();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error starting recording: $e';
      });
      _playErrorCue();
    }
  }

  Future<void> _stopAndSendRecording() async {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      setState(() {
        _isRecording = false;
        _isLoading = true;
        _statusText = 'Searching database...';
      });

      final path = await _audioRecorder.stop();

      _silencePlayer.resume();

      if (path != null && path.isNotEmpty) {
        await _sendAudioToBackend(path);
      } else {
        setState(() {
          _isLoading = false;
          _statusText = 'Error: Recording failed or path was empty.';
        });
        _playErrorCue();
      }
    } catch (e) {
      _silencePlayer.resume();
      setState(() {
        _isLoading = false;
        _statusText = 'Error stopping recording: $e';
      });
      _playErrorCue();
    }
  }

  Future<void> _sendAudioToBackend(String path) async {
    final uri = Uri.parse(_backendUrl);
    var request = http.MultipartRequest('POST', uri);

    // Pass chosen language to backend
    request.fields['language'] = _selectedLanguage;

    try {
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        final bytes = response.bodyBytes;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'recording.wav',
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final String title = data['title'] ?? 'Unknown Title';
          final String artist = data['artist'] ?? 'Unknown Artist';

          setState(() {
            _songTitle = title;
            _artist = artist;
            _spotifyUrl = data['spotify_url'];
            _appleMusicUrl = data['apple_music_url'];
            _statusText = 'Match Found!';
          });

          await _saveToHistory('$title - $artist');

          // Open in preferred music app automatically
          if (_preferredMusicApp == 'apple_music' &&
              _appleMusicUrl != null &&
              _appleMusicUrl!.isNotEmpty) {
            _openMusicUrl(_appleMusicUrl!);
          } else if (_spotifyUrl != null && _spotifyUrl!.isNotEmpty) {
            _openSpotifyNative(_spotifyUrl!);
          }
        } else {
          _playErrorCue();
          setState(() {
            _statusText =
                data['message'] ?? 'No match found. Try singing clearly!';
          });
        }
      } else {
        _playErrorCue();
        setState(() {
          _statusText = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      _playErrorCue();
      setState(() {
        _isLoading = false;
        _statusText = 'Failed to connect to backend: $e';
      });
    }
  }

  Future<void> _openSpotifyNative(String url) async {
    String finalUrl = url;
    if (url.startsWith('spotify:track:')) {
      final trackId = url.replaceFirst('spotify:track:', '');
      finalUrl = 'spotify:track:$trackId';
    }
    _openMusicUrl(finalUrl);
  }

  Future<void> _openMusicUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hands-Free Song Identifier'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'App Preferences',
            onPressed: _showPreferencesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Search History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Where Are You?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: EnvironmentMode.values.map((mode) {
                  final isSelected = _selectedMode == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: InkWell(
                      onTap: _isRecording || _isLoading
                          ? null
                          : () {
                              _saveMode(mode);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepPurple.shade50
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mode.icon,
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${mode.duration}s',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopAndSendRecording();
                    } else {
                      _startRecording(playDing: true);
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor:
                        _isRecording ? Colors.red : Colors.deepPurple,
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  '💡 Tip: Say "Hey Siri, find song with Reczt" to open the app and instantly start finding the song stuck in your head!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              if (_songTitle != null && _artist != null) ...[
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.music_note,
                            size: 60, color: Colors.deepPurple),
                        const SizedBox(height: 12),
                        Text(
                          _songTitle!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'by $_artist',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (_preferredMusicApp == 'apple_music' &&
                            _appleMusicUrl != null &&
                            _appleMusicUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFA243C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _openMusicUrl(_appleMusicUrl!),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Open in Apple Music'),
                          )
                        else if (_spotifyUrl != null &&
                            _spotifyUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _openSpotifyNative(_spotifyUrl!),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Open in Spotify App'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// SEARCH HISTORY PAGE
// ----------------------------------------------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('song_history') ?? [];
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('song_history');
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search History'),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text(
                        'Are you sure you want to delete all saved song searches?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(
              child: Text(
                'No songs searched yet!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final songEntry = _history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.music_note, color: Colors.white),
                    ),
                    title: Text(
                      songEntry,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ----------------------------------------------------
// AIRPODS AUDIO HANDLER
// ----------------------------------------------------
class AirPodsAudioHandler extends BaseAudioHandler {
  final VoidCallback onMediaButtonTriggered;

  AirPodsAudioHandler({required this.onMediaButtonTriggered}) {
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.play, MediaControl.pause],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
        },
        processingState: AudioProcessingState.ready,
        playing: true,
      ),
    );
  }

  @override
  Future<void> play() async {
    onMediaButtonTriggered();
    return super.play();
  }

  @override
  Future<void> pause() async {
    onMediaButtonTriggered();
    return super.pause();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    onMediaButtonTriggered();
    return super.click(button);
  }
}