import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ResponderAckEvent {
  final String incidentId;
  final String ackToken;
  final String message;
  final int? sourceNode;
  final int? packetId;
  final int timestamp;

  ResponderAckEvent({
    required this.incidentId,
    required this.ackToken,
    required this.message,
    this.sourceNode,
    this.packetId,
    required this.timestamp,
  });
}

class EocWebSocketClient {
  final String? _explicitUrl;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  final _ackStreamController = StreamController<ResponderAckEvent>.broadcast();
  Stream<ResponderAckEvent> get ackStream => _ackStreamController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get isConnectedStream => _connectionStateController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  EocWebSocketClient({String? url}) : _explicitUrl = url;

  String? get _websocketUrl {
    if (_explicitUrl != null && _explicitUrl.isNotEmpty) {
      return _explicitUrl;
    }
    if (!AppConfig.isServerConfigured) return null;

    final baseUrl = AppConfig.serverBaseUrl.trim();
    String wsBase;
    if (baseUrl.startsWith('https://')) {
      wsBase = 'wss://${baseUrl.substring('https://'.length)}';
    } else if (baseUrl.startsWith('http://')) {
      wsBase = 'ws://${baseUrl.substring('http://'.length)}';
    } else {
      return null;
    }

    while (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }
    return '$wsBase/api/v1/ws/stream';
  }

  void connect() {
    if (_isDisposed) return;
    final url = _websocketUrl;
    if (url == null || url.isEmpty) {
      // Server not configured; stay honestly disconnected
      return;
    }
    _connectInternal(url);
  }

  Future<void> _connectInternal(String url) async {
    if (_isConnecting || _isConnected || _isDisposed) return;
    _isConnecting = true;

    try {
      if (kIsWeb) {
        _isConnecting = false;
        return;
      }
      final socket = await WebSocket.connect(url).timeout(const Duration(seconds: 15));
      _socket = socket;
      _socket!.pingInterval = const Duration(seconds: 20);
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);

      _socket!.listen(
        (data) {
          _handleMessage(data);
        },
        onDone: () {
          _onDisconnected();
        },
        onError: (err) {
          _onDisconnected();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _isConnecting = false;
      _onDisconnected();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final text = data is String ? data : utf8.decode(data as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;

      final event = decoded['event'] as String?;
      final action = decoded['action'] as String?;

      if (event == 'RESPONDER_ACK' || action == 'ACKNOWLEDGE') {
        final rawId = decoded['incident_id'] as String? ?? decoded['id'] as String?;
        final rawToken = decoded['ack_token'] as String?;
        final msg = decoded['message'] as String? ?? 'Acknowledged by EOC responder';
        final sourceNode = decoded['source_node'] as int?;
        final packetId = decoded['packet_id'] as int?;
        final ts = decoded['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final incidentId = rawId ?? (rawToken != null && rawToken.startsWith('ACK-') ? rawToken.substring(4) : '');
        final ackToken = rawToken ?? (incidentId.isNotEmpty ? 'ACK-$incidentId' : '');

        if (incidentId.isNotEmpty || ackToken.isNotEmpty) {
          _ackStreamController.add(
            ResponderAckEvent(
              incidentId: incidentId,
              ackToken: ackToken,
              message: msg,
              sourceNode: sourceNode,
              packetId: packetId,
              timestamp: ts,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionStateController.add(false);
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    _reconnectAttempts++;
    final backoffSec = min(30, pow(2, min(_reconnectAttempts - 1, 5)).toInt());
    final jitterMs = Random().nextInt(1000);
    final delay = Duration(seconds: backoffSec, milliseconds: jitterMs);

    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _ackStreamController.close();
    _connectionStateController.close();
  }
}
