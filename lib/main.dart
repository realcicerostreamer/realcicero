import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.storage.request();
  await Permission.internet.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'realCicero',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const StreamScreen(),
    );
  }
}

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  _StreamScreenState createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _cameraUrlController = TextEditingController(text: 'rtsp://192.168.42.1/live');
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _twitchController = TextEditingController();
  final TextEditingController _kickController = TextEditingController();
  
  bool _isStreaming = false;
  bool _isConnected = false;
  String _statusMessage = 'Desconectado';
  int _selectedTab = 0;
  late TabController _tabController;
  
  // URLs para os chats
  String _youtubeChatUrl = '';
  String _twitchChatUrl = '';
  String _kickChatUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cameraUrlController.text = prefs.getString('cameraUrl') ?? 'rtsp://192.168.42.1/live';
      _youtubeController.text = prefs.getString('youtubeRtmp') ?? '';
      _twitchController.text = prefs.getString('twitchRtmp') ?? '';
      _kickController.text = prefs.getString('kickRtmp') ?? '';
      _youtubeChatUrl = prefs.getString('youtubeChatUrl') ?? '';
      _twitchChatUrl = prefs.getString('twitchChatUrl') ?? '';
      _kickChatUrl = prefs.getString('kickChatUrl') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cameraUrl', _cameraUrlController.text);
    await prefs.setString('youtubeRtmp', _youtubeController.text);
    await prefs.setString('twitchRtmp', _twitchController.text);
    await prefs.setString('kickRtmp', _kickController.text);
    await prefs.setString('youtubeChatUrl', _youtubeChatUrl);
    await prefs.setString('twitchChatUrl', _twitchChatUrl);
    await prefs.setString('kickChatUrl', _kickChatUrl);
  }

  Future<void> _startStreaming() async {
    if (_cameraUrlController.text.isEmpty) {
      _showMessage('URL da câmera não pode estar vazia');
      return;
    }

    // Verificar se pelo menos uma plataforma está configurada
    if (_youtubeController.text.isEmpty && 
        _twitchController.text.isEmpty && 
        _kickController.text.isEmpty) {
      _showMessage('Configure pelo menos uma URL RTMP');
      return;
    }

    setState(() {
      _isStreaming = true;
      _statusMessage = 'Iniciando transmissão...';
    });

    await _saveSettings();

    // Construir lista de destinos RTMP
    List<String> rtmpDestinations = [];
    if (_youtubeController.text.isNotEmpty) {
      rtmpDestinations.add(_youtubeController.text);
    }
    if (_twitchController.text.isNotEmpty) {
      rtmpDestinations.add(_twitchController.text);
    }
    if (_kickController.text.isNotEmpty) {
      rtmpDestinations.add(_kickController.text);
    }

    // Configurar comando FFmpeg para streaming múltiplo
    String ffmpegCommand = '-i ${_cameraUrlController.text} ';
    
    // Adicionar configurações de vídeo otimizadas para 720p e baixa latência
    ffmpegCommand += '-c:v libx264 -preset ultrafast -tune zerolatency ';
    ffmpegCommand += '-r 30 -g 60 -b:v 2500k -bufsize 2500k -maxrate 2500k ';
    ffmpegCommand += '-s 1280x720 -aspect 16:9 ';
    ffmpegCommand += '-c:a aac -b:a 128k -ar 44100 ';
    
    // Adicionar saídas para cada destino RTMP
    for (int i = 0; i < rtmpDestinations.length; i++) {
      if (i > 0) {
        ffmpegCommand += ' -map 0:v -map 0:a ';
        ffmpegCommand += '-c:v libx264 -preset ultrafast -tune zerolatency ';
        ffmpegCommand += '-r 30 -g 60 -b:v 2500k -bufsize 2500k -maxrate 2500k ';
        ffmpegCommand += '-s 1280x720 -aspect 16:9 ';
        ffmpegCommand += '-c:a aac -b:a 128k -ar 44100 ';
      }
      ffmpegCommand += '-f flv "${rtmpDestinations[i]}" ';
    }

    // Executar FFmpeg
    FFmpegKit.executeAsync(
      ffmpegCommand,
      (session) async {
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            _statusMessage = 'Transmissão finalizada com sucesso';
            _isStreaming = false;
          });
        } else if (ReturnCode.isCancel(returnCode)) {
          setState(() {
            _statusMessage = 'Transmissão cancelada';
            _isStreaming = false;
          });
        } else {
          setState(() {
            _statusMessage = 'Erro na transmissão';
            _isStreaming = false;
          });
        }
      },
      (log) {
        print("FFmpeg Log: ${log.getMessage()}");
      },
      (statistics) {
        setState(() {
          _statusMessage = 'Transmitindo... ${statistics.getTime() / 1000}s';
        });
      }
    );
  }

  Future<void> _stopStreaming() async {
    await FFmpegKit.cancel();
    setState(() {
      _isStreaming = false;
      _statusMessage = 'Transmissão interrompida';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _updateChatUrls() {
    // Extrair IDs dos streams das URLs RTMP e gerar URLs de chat
    // Exemplo simplificado - na prática, precisaria de regex mais robustos
    
    // YouTube
    if (_youtubeController.text.contains('live2/')) {
      final parts = _youtubeController.text.split('live2/');
      if (parts.length > 1) {
        final streamKey = parts[1].trim();
        _youtubeChatUrl = 'https://www.youtube.com/live_chat?v=$streamKey';
      }
    }
    
    // Twitch
    if (_twitchController.text.contains('twitch.tv/')) {
      final parts = _twitchController.text.split('twitch.tv/');
      if (parts.length > 1) {
        final channelKey = parts[1].split('?').first.trim();
        _twitchChatUrl = 'https://www.twitch.tv/embed/$channelKey/chat?parent=streamernews.example.com';
      }
    }
    
    // Kick (simplificado)
    if (_kickController.text.contains('kick.com/')) {
      final parts = _kickController.text.split('kick.com/');
      if (parts.length > 1) {
        final channelName = parts[1].split('/').first.trim();
        _kickChatUrl = 'https://kick.com/$channelName/chatroom';
      }
    }
    
    _saveSettings();
  }

  @override
  void dispose() {
    _cameraUrlController.dispose();
    _youtubeController.dispose();
    _twitchController.dispose();
    _kickController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('realCicero Multistreaming'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.videocam), text: 'Câmera'),
            Tab(icon: Icon(Icons.chat), text: 'YouTube'),
            Tab(icon: Icon(Icons.chat), text: 'Twitch'),
            Tab(icon: Icon(Icons.chat), text: 'Kick'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Configuração da câmera e streaming
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('URL da Câmera COOAU CU-SPC06:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _cameraUrlController,
                  decoration: const InputDecoration(
                    hintText: 'rtsp://192.168.42.1/live',
                    helperText: 'URL RTSP da sua câmera',
                  ),
                  enabled: !_isStreaming,
                ),
                const SizedBox(height: 20),
                
                const Text('YouTube RTMP URL:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _youtubeController,
                  decoration: const InputDecoration(
                    hintText: 'rtmp://a.rtmp.youtube.com/live2/xxxx-xxxx-xxxx-xxxx',
                    helperText: 'URL RTMP do YouTube com chave',
                  ),
                  enabled: !_isStreaming,
                ),
                
                const SizedBox(height: 10),
                const Text('Twitch RTMP URL:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _twitchController,
                  decoration: const InputDecoration(
                    hintText: 'rtmp://live.twitch.tv/app/live_xxxxxxxxxx',
                    helperText: 'URL RTMP da Twitch com chave',
                  ),
                  enabled: !_isStreaming,
                ),
                
                const SizedBox(height: 10),
                const Text('Kick RTMP URL:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _kickController,
                  decoration: const InputDecoration(
                    hintText: 'rtmp://live.kick.com/live/xxxxxxxxxx',
                    helperText: 'URL RTMP do Kick com chave',
                  ),
                  enabled: !_isStreaming,
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: !_isStreaming ? () {
                    _updateChatUrls();
                    _startStreaming();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('INICIAR TRANSMISSÃO'),
                ),
                
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isStreaming ? _stopStreaming : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('PARAR TRANSMISSÃO'),
                ),
                
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $_statusMessage',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text(
                        'Configuração: 1280x720, 30fps, baixa latência',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tab 2: Chat do YouTube
          _buildChatWebView(_youtubeChatUrl, 'YouTube'),
          
          // Tab 3: Chat da Twitch
          _buildChatWebView(_twitchChatUrl, 'Twitch'),
          
          // Tab 4: Chat do Kick
          _buildChatWebView(_kickChatUrl, 'Kick'),
        ],
      ),
    );
  }
  
  Widget _buildChatWebView(String url, String platform) {
    if (url.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Chat do $platform não disponível',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure a URL RTMP e inicie a transmissão',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return InAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse(url)),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
      ),
      onWebViewCreated: (controller) {
        // Pode adicionar lógica adicional aqui se necessário
      },
      onLoadError: (controller, url, code, message) {
        print("Erro ao carregar chat: $message");
      },
    );
  }
}
