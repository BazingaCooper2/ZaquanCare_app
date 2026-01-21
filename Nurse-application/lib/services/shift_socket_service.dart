import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/shift_offer.dart';

/// Production-grade WebSocket service for real-time shift offers
/// Features:
/// - Auto-reconnection with exponential backoff
/// - Connection state management
/// - Error handling and recovery
/// - Graceful shutdown
class ShiftSocketService {
  final int empId;
  final String wsUrl;

  WebSocketChannel? _channel;
  StreamController<ShiftOffer>? _offerController;
  StreamController<SocketConnectionState>? _connectionStateController;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  bool _manualDisconnect = false;

  // Reconnection configuration
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 2; // seconds
  static const int _maxReconnectDelay = 30; // seconds

  /// Stream of incoming shift offers
  Stream<ShiftOffer> get offerStream => _offerController!.stream;

  /// Stream of connection state changes
  Stream<SocketConnectionState> get connectionStateStream =>
      _connectionStateController!.stream;

  SocketConnectionState _currentState = SocketConnectionState.disconnected;
  SocketConnectionState get currentState => _currentState;

  ShiftSocketService({
    required this.empId,
    required this.wsUrl,
  }) {
    _offerController = StreamController<ShiftOffer>.broadcast();
    _connectionStateController =
        StreamController<SocketConnectionState>.broadcast();
  }

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_isDisposed || _manualDisconnect) return;

    if (_currentState == SocketConnectionState.connecting ||
        _currentState == SocketConnectionState.connected) {
      debugPrint('🔌 Already connected or connecting');
      return;
    }

    try {
      _updateConnectionState(SocketConnectionState.connecting);
      debugPrint('🔌 Connecting to WebSocket: $wsUrl/$empId');

      final uri = Uri.parse('$wsUrl/$empId');
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to establish or fail
      await _channel!.ready;

      _updateConnectionState(SocketConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection

      debugPrint('✅ WebSocket connected successfully');

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('❌ WebSocket connection error: $e');
      _updateConnectionState(SocketConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      debugPrint('📨 Received message: $data');

      final messageType = data['type'] as String?;

      if (messageType == 'shift_offer') {
        final offer = ShiftOffer.fromJson(data);
        _offerController?.add(offer);
        debugPrint('✅ Shift offer received: ${offer.shiftId}');
      } else if (messageType == 'ping') {
        // Respond to ping to keep connection alive
        send({'type': 'pong'});
      } else {
        debugPrint('ℹ️ Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('❌ Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    _updateConnectionState(SocketConnectionState.error);
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    debugPrint('🔌 WebSocket disconnected');

    if (!_isDisposed && !_manualDisconnect) {
      _updateConnectionState(SocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_isDisposed || _manualDisconnect) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      _updateConnectionState(SocketConnectionState.error);
      return;
    }

    _reconnectAttempts++;

    // Calculate delay with exponential backoff
    final delay = (_baseReconnectDelay * (1 << (_reconnectAttempts - 1)))
        .clamp(0, _maxReconnectDelay);

    debugPrint(
        '🔄 Reconnecting in $delay seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      connect();
    });
  }

  /// Send data through WebSocket
  void send(Map<String, dynamic> data) {
    if (_currentState != SocketConnectionState.connected) {
      debugPrint('⚠️ Cannot send: WebSocket not connected');
      return;
    }

    try {
      final message = jsonEncode(data);
      _channel?.sink.add(message);
      debugPrint('📤 Sent message: $message');
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(SocketConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController?.add(newState);
      debugPrint('🔄 Connection state: $newState');
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();

    try {
      await _channel?.sink.close(status.goingAway);
      debugPrint('👋 WebSocket disconnected gracefully');
    } catch (e) {
      debugPrint('⚠️ Error during disconnect: $e');
    }

    _updateConnectionState(SocketConnectionState.disconnected);
  }

  /// Dispose and clean up resources
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _offerController?.close();
    _connectionStateController?.close();
    debugPrint('🗑️ ShiftSocketService disposed');
  }
}

/// WebSocket connection states
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
