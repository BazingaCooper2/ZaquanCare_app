import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TokenDisplayPage extends StatefulWidget {
  const TokenDisplayPage({super.key});

  @override
  State<TokenDisplayPage> createState() => _TokenDisplayPageState();
}

class _TokenDisplayPageState extends State<TokenDisplayPage> {
  String? _fcmToken;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getToken();
  }

  Future<void> _getToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    setState(() {
      _fcmToken = token;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Token'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  _fcmToken ?? 'Failed to get token',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
      ),
    );
  }
}
