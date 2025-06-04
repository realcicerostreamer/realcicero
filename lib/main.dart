// Created by Cicero
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealCiceroApp());
}

class RealCiceroApp extends StatelessWidget {
  const RealCiceroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'realCicero',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cameraUrlController = TextEditingController(text: 'rtsp://192.168.1.1/live');
  final TextEditingController _youtubeRtmpController = TextEditingController();
  final TextEditingController _twitchRtmpController = TextEditingController();
  final TextEditingController _kickRtmpController = TextEditingController();
  final TextEditingController _youtubeChatController = TextEditingController();
  final TextEditingController _twitchChatController = TextEditingController();
  final TextEditingController _kickChatController = TextEditingController();
  bool _isStreaming = false;
  VlcPlayerController? _vlcController;
  final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  String _connectionStatus = 'Not connected';

  @override
  void initState() {
    super.initState();
    // Initialize WebView for chats
    WebviewFlutterPlatform.instance;
    // Initialize VLC player
    _updateVlcController();
  }

  // Update VLC controller with new URL
  void _updateVlcController() {
    setState(() {
      _vlcController = VlcPlayerController.network(
        _cameraUrlController.text,
        autoPlay: true,
        onInit: () {
          setState(() {});
        },
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOption('--network-caching=1000'),
          ]),
        ),
      );
    });
  }

  // Check camera connection
  Future<bool> _checkCameraConnection() async {
    try {
      // Try to access a common camera status endpoint (e.g., GoPro)
      final response = await http.get(Uri.parse('http://${_cameraUrlController.text.split('/')[2]}/status')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = 'Connected to camera';
        });
        return true;
      }
      setState(() {
        _connectionStatus = 'Failed to connect (HTTP)';
      });
      return false;
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection error: $e';
      });
      // Fallback to checking stream availability
      final result = await _ffmpeg.execute('-i "${_cameraUrlController.text}" -t 1 -f null -');
      return result == 0;
    }
  }

  // Start streaming to RTMP destinations
  Future<void> _startStreaming() async {
    if (_cameraUrlController.text.isEmpty ||
        _youtubeRtmpController.text.isEmpty ||
        _twitchRtmpController.text.isEmpty ||
        _kickRtmpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all RTMP URLs and Camera URL')),
      );
      return;
    }

    if (!(await _checkCameraConnection())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to camera. Check Wi-Fi and URL.')),
      );
      return;
    }

    setState(() {
      _isStreaming = true;
    });

    // FFmpeg command for multistreaming with watermark
    String command = '-i "${_cameraUrlController.text}" '
        '-vf "drawtext=text=\'Created by Cicero\':fontcolor=white:fontsize=20:x=w-tw-10:y=h-th-10:box=1:boxcolor=black@0.5" '
        '-c:v libx264 -b:v 2000k -c:a aac -b:a 128k '
        '-f flv "${_youtubeRtmpController.text}" '
        '-f flv "${_twitchRtmpController.text}" '
        '-f flv "${_kickRtmpController.text}"';

    try {
      await _ffmpeg.execute(command);
    } catch (e) {
      print('Streaming error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Streaming error: $e')),
      );
      setState(() {
        _isStreaming = false;
      });
    }
  }

  // Stop streaming
  void _stopStreaming() {
    setState(() {
      _isStreaming = false;
    });
    _ffmpeg.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('realCicero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _updateVlcController();
              _checkCameraConnection();
            },
            tooltip: 'Refresh Camera Stream',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status
              Text(
                'Camera Status: $_connectionStatus',
                style: TextStyle(
                  color: _connectionStatus.startsWith('Connected') ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Video Preview
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _vlcController != null
                    ? VlcPlayer(
                        controller: _vlcController!,
                        aspectRatio: 16 / 9,
                        placeholder: const Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox(height: 200, child: Center(child: Text('Loading video...'))),
              ),
              const SizedBox(height: 16),
              // Camera URL Input
              TextField(
                controller: _cameraUrlController,
                decoration: const InputDecoration(
                  labelText: 'Camera Stream URL (RTSP/UDP/HTTP)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., rtsp://192.168.1.1/live or udp://192.168.1.1:8554',
                ),
                onChanged: (value) {
                  _updateVlcController();
                  _checkCameraConnection();
                },
              ),
              const SizedBox(height: 16),
              // RTMP URLs Inputs
              TextField(
                controller: _youtubeRtmpController,
                decoration: const InputDecoration(
                  labelText: 'YouTube RTMP URL',
                  border: OutlineInputBorder(),
                  hintText: 'rtmp://a.rtmp.youtube.com/live2/your-stream-key',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _twitchRtmpController,
                decoration: const InputDecoration(
                  labelText: 'Twitch RTMP URL',
                  border: OutlineInputBorder(),
                  hintText: 'rtmp://live.twitch.tv/app/your-stream-key',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _kickRtmpController,
                decoration: const InputDecoration(
                  labelText: 'Kick RTMP URL',
                  border: OutlineInputBorder(),
                  hintText: 'rtmp://ingest.kick.com/app/your-stream-key',
                ),
              ),
              const SizedBox(height: 16),
              // Chat URLs Inputs
              TextField(
                controller: _youtubeChatController,
                decoration: const InputDecoration(
                  labelText: 'YouTube Chat URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://www.youtube.com/live_chat?v=YOUR_YOUTUBE_VIDEO_ID',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _twitchChatController,
                decoration: const InputDecoration(
                  labelText: 'Twitch Chat URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://www.twitch.tv/embed/YOUR_TWITCH_CHANNEL/chat?darkpopout',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _kickChatController,
                decoration: const InputDecoration(
                  labelText: 'Kick Chat URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://kick.com/YOUR_KICK_CHANNEL?popout=true',
                ),
              ),
              const SizedBox(height: 16),
              // Start/Stop Streaming Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isStreaming ? null : _startStreaming,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Start Streaming', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isStreaming ? _stopStreaming : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Stop Streaming', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chat Section
              const Text('Live Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: ListView(
                  children: [
                    if (_youtubeChatController.text.isNotEmpty) ...[
                      const Text('YouTube Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 100,
                        child: WebViewWidget(
                          controller: WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..loadRequest(Uri.parse(_youtubeChatController.text)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_twitchChatController.text.isNotEmpty) ...[
                      const Text('Twitch Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 100,
                        child: WebViewWidget(
                          controller: WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..loadRequest(Uri.parse(_twitchChatController.text)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_kickChatController.text.isNotEmpty) ...[
                      const Text('Kick Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 100,
                        child: WebViewWidget(
                          controller: WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..loadRequest(Uri.parse(_kickChatController.text)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Created by Cicero',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraUrlController.dispose();
    _youtubeRtmpController.dispose();
    _twitchRtmpController.dispose();
    _kickRtmpController.dispose();
    _youtubeChatController.dispose();
    _twitchChatController.dispose();
    _kickChatController.dispose();
    _vlcController?.dispose();
    super.dispose();
  }
