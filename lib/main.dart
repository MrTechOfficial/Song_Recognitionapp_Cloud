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
import 'package:url_launcher/url_launcher.dart';

void main() async {
  // ⚡ Required for native hardware & audio service initialization
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

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _dingPlayer;
  late final AudioPlayer _errorPlayer; // 🔊 Player for error sound
  AirPodsAudioHandler? _airPodsHandler;

  bool _isRecording = false;
  bool _isLoading = false;

  int _secondsRemaining = 12;
  Timer? _autoStopTimer;
  Timer? _countdownTimer;

  String _statusText =
      'Tap the mic or squeeze your AirPods stem to start listening!';
  String? _songTitle;
  String? _artist;
  String? _spotifyUrl;

  // 🔗 UPDATE YOUR BACKEND URL HERE (IP Address, Dev Tunnel, or Cloud Domain)
  final String _backendUrl =
      'https://song-recognitionapp-cloud.onrender.com/recognize';

  // 🎵 Audio Cue URLs
  final String _dingUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
  final String _errorSoundUrl =
      'https://assets.mixkit.co/active_storage/sfx/2873/2873-preview.mp3'; // ❌ Error sound effect

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _dingPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer(); // Initialize error player

    if (!kIsWeb) {
      _initAirPodsListener();
    }
  }

  Future<void> _initAirPodsListener() async {
    try {
      _airPodsHandler = await AudioService.init(
        builder: () => AirPodsAudioHandler(
          onMediaButtonTriggered: () {
            if (!_isRecording && !_isLoading) {
              _startRecording();
            } else if (_isRecording) {
              _stopAndSendRecording();
            }
          },
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.example.song_recognition.channel.audio',
          androidNotificationChannelName: 'AirPods Song Finder',
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      debugPrint('AirPods listener setup notice: $e');
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    _dingPlayer.dispose();
    _errorPlayer.dispose();
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

  // ❌ Triggers the error sound effect when database search fails
  Future<void> _playErrorCue() async {
    try {
      await _errorPlayer.play(UrlSource(_errorSoundUrl));
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Error playing failure sound: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (kIsWeb || await Permission.microphone.request().isGranted) {
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

        setState(() {
          _isRecording = true;
          _secondsRemaining = 12;
          _statusText = 'Listening... (12s remaining)';
          _songTitle = null;
          _artist = null;
          _spotifyUrl = null;
        });

        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_secondsRemaining > 1) {
              _secondsRemaining--;
              _statusText = 'Listening... (${_secondsRemaining}s remaining)';
            } else {
              _countdownTimer?.cancel();
            }
          });
        });

        _autoStopTimer = Timer(const Duration(seconds: 12), () {
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

    _playDingCue();

    try {
      setState(() {
        _isRecording = false;
        _isLoading = true;
        _statusText = 'Searching database...';
      });

      final path = await _audioRecorder.stop();

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
          setState(() {
            _songTitle = data['title'];
            _artist = data['artist'];
            _spotifyUrl = data['spotify_url'];
            _statusText = 'Match Found! Launching Spotify...';
          });

          if (_spotifyUrl != null && _spotifyUrl!.isNotEmpty) {
            _openSpotifyNative(_spotifyUrl!);
          }
        } else {
          // ❌ Database search returned no match
          _playErrorCue();
          setState(() {
            _statusText =
                data['message'] ?? 'No match found. Try singing clearly!';
          });
        }
      } else {
        // ❌ Server HTTP Error
        _playErrorCue();
        setState(() {
          _statusText = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      // ❌ Connection Error
      _playErrorCue();
      setState(() {
        _isLoading = false;
        _statusText = 'Failed to connect to backend: $e';
      });
    }
  }

  Future<void> _openSpotifyNative(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⛷️ Hands-Free Song Finder'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopAndSendRecording();
                    } else {
                      _startRecording();
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
              const SizedBox(height: 40),
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
                        if (_spotifyUrl != null && _spotifyUrl!.isNotEmpty)
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

// 🎧 Hardware AirPods media control handler
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
        playing: false,
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