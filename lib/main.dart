import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamScreen(),
    );
  }
}

class StreamScreen extends StatefulWidget {
  @override
  _StreamScreenState createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      'rtsp://192.168.1.1:554/live', // URL da COOAU
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('realCicero Stream')),
      body: Center(
        child: VlcPlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
          placeholder: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
