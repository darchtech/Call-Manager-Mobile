import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/config.dart';
import 'network_service.dart';
import 'auth_service.dart';

class WebSocketService extends GetxService {
  static WebSocketService get instance => Get.find<WebSocketService>();

  IO.Socket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Configuration
  static const int _heartbeatInterval = 25000; // 25 seconds
  static const int _reconnectDelay = 5000; // 5 seconds
  static const int _maxReconnectAttempts = 10;

  // State management
  final RxBool _isConnected = false.obs;
  final RxBool _isConnecting = false.obs;
  final RxString _connectionStatus = 'Disconnected'.obs;
  final RxInt _reconnectAttempts = 0.obs;
  final RxString _lastError = ''.obs;
  final RxString _serverTime = ''.obs;
  final RxInt _latency = 0.obs;

  // Dependencies
  late final NetworkService _networkService;

  // Connection info
  String? _authToken;
  String? _serverUrl;
  DateTime? _lastPingTime;
  DateTime? _lastPongTime;

  // Getters
  bool get isConnected => _isConnected.value;
  bool get isConnecting => _isConnecting.value;
  String get connectionStatus => _connectionStatus.value;
  int get reconnectAttempts => _reconnectAttempts.value;
  String get lastError => _lastError.value;
  String get serverTime => _serverTime.value;
  int get latency => _latency.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    _networkService = NetworkService.instance;

    print('[WebSocket] Service initialized');
  }

  /// Connect to WebSocket server
  Future<bool> connect() async {
    if (_isConnecting.value || _isConnected.value) {
      print('[WebSocket] Already connecting or connected');
      return _isConnected.value;
    }

    if (!_networkService.isConnected) {
      print('[WebSocket] No network connection available');
      _connectionStatus.value = 'No Network';
      return false;
    }

    _isConnecting.value = true;
    _connectionStatus.value = 'Connecting...';
    _lastError.value = '';

    try {
      // Get auth token
      _authToken = await _getAuthToken();
      print(
        '[WebSocket] Token present: ${_authToken != null && _authToken!.isNotEmpty}',
      );
      if (_authToken == null || _authToken!.isEmpty) {
        print(
          '[WebSocket] No token yet; will attempt unauthenticated connect (may be rejected)',
        );
      }

      // Get server URL
      _serverUrl = await _getServerUrl();
      if (_serverUrl == null) {
        throw Exception('Server URL not configured');
      }
      print('[WebSocket] Using server URL: $_serverUrl');

      // Connect with socket.io
      print('[WebSocket] Connecting (socket.io) to: $_serverUrl');
      _socket = IO.io(
        _serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': _authToken})
            .setExtraHeaders(
              _authToken != null && _authToken!.isNotEmpty
                  ? {'Authorization': 'Bearer ${_authToken!}'}
                  : {},
            )
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .setReconnectionAttempts(0) // 0 = infinite
            .enableForceNew()
            .setTimeout(10000) // 10 second connection timeout
            .build(),
      );

      _socket!.on('connect', (_) {
        _isConnected.value = true;
        _isConnecting.value = false;
        _connectionStatus.value = 'Connected';
        _reconnectAttempts.value = 0;
        _lastError.value = '';
        _startHeartbeat();
        print('[WebSocket] Socket.io connected (id: ${_socket!.id})');
      });

      _socket!.on('disconnect', (reason) {
        _handleDisconnect();
        print('[WebSocket] Socket.io disconnected: $reason');
      });

      _socket!.on('connect_error', (err) {
        print('[WebSocket] connect_error: $err');
        print('[WebSocket] Error details: ${err.toString()}');
        print('[WebSocket] Server URL: $_serverUrl');
        print(
          '[WebSocket] Auth token present: ${_authToken != null && _authToken!.isNotEmpty}',
        );
        _handleError(err);
      });

      _socket!.on('reconnect_attempt', (attempt) {
        print('[WebSocket] reconnect_attempt: $attempt');
      });
      _socket!.on('reconnect_error', (err) {
        print('[WebSocket] reconnect_error: $err');
      });
      _socket!.on('reconnect_failed', (_) {
        print('[WebSocket] reconnect_failed');
      });

      _socket!.onAny((event, data) {
        print('[WebSocket] Event received: $event');
        _handleMessage({
          'event': event,
          'data': data,
          'serverTime': DateTime.now().toIso8601String(),
        });
      });

      // Wait briefly; real connection confirmed in 'connect'
      return true;
    } catch (e) {
      _isConnecting.value = false;
      _connectionStatus.value = 'Connection Failed';
      _lastError.value = e.toString();
      print('[WebSocket] Connection failed: $e');

      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    _disconnect();
  }

  /// Send message to server
  void sendMessage(String event, Map<String, dynamic> data) {
    if (!_isConnected.value || _socket == null) {
      print('[WebSocket] Cannot send message - not connected');
      return;
    }

    try {
      _socket!.emit(event, data);
      print('[WebSocket] Sent message: $event');
    } catch (e) {
      print('[WebSocket] Error sending message: $e');
      _lastError.value = 'Send error: $e';
    }
  }

  /// Send ping to server
  void _sendPing() {
    if (_isConnected.value && _socket != null) {
      _lastPingTime = DateTime.now();
      _socket!.emitWithAck(
        'ping',
        {
          'clientTime': _lastPingTime!.toIso8601String(),
          'latency': _latency.value,
        },
        ack: (data) {
          _handleServerPong(data);
        },
      );
      print('[WebSocket] Ping sent to server');
    }
  }

  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      Map<String, dynamic> dataMap;
      if (message is String) {
        dataMap = Map<String, dynamic>.from(jsonDecode(message));
      } else if (message is Map) {
        dataMap = Map<String, dynamic>.from(message);
      } else {
        print('[WebSocket] Unrecognized message type: ${message.runtimeType}');
        return;
      }
      final event = dataMap['event'] ?? 'message';
      final payload = dataMap['data'] ?? {};

      // Update server time
      if (dataMap['serverTime'] != null) {
        _serverTime.value = dataMap['serverTime'];
      }

      switch (event) {
        case 'connected':
          _handleConnected(payload);
          break;
        case 'ping':
          _handleServerPing(payload);
          break;
        case 'pong':
          _handleServerPong(payload);
          break;
        case 'leadStatus:event':
          _handleLeadStatusEvent(payload);
          break;
        case 'lead:event':
          _handleLeadEvent(payload);
          break;
        default:
          print('[WebSocket] Unknown event: $event');
      }
    } catch (e) {
      print('[WebSocket] Error handling message: $e');
    }
  }

  /// Handle connection confirmation
  void _handleConnected(Map<String, dynamic> data) {
    print('[WebSocket] Connection confirmed by server');
    _connectionStatus.value = 'Connected';
    _lastError.value = '';
  }

  /// Handle server ping
  void _handleServerPing(Map<String, dynamic> data) {
    print('[WebSocket] Ping received from server');
    // Respond with pong
    sendMessage('pong', {
      'clientTime': DateTime.now().toIso8601String(),
      'serverData': data,
    });
  }

  /// Handle server pong
  void _handleServerPong(Map<String, dynamic> data) {
    _lastPongTime = DateTime.now();

    if (_lastPingTime != null) {
      final latency = _lastPongTime!.difference(_lastPingTime!).inMilliseconds;
      _latency.value = latency;
      print('[WebSocket] Pong received - Latency: ${latency}ms');
    }

    // Pong received successfully
  }

  /// Handle lead status events
  void _handleLeadStatusEvent(Map<String, dynamic> data) {
    print('[WebSocket] Lead status event received: ${data['type']}');
    // TODO: Handle lead status updates
    // This will be implemented when we add real-time lead status sync
  }

  /// Handle lead events
  void _handleLeadEvent(Map<String, dynamic> data) {
    print('[WebSocket] Lead event received: ${data['type']}');
    // TODO: Handle lead updates
    // This will be implemented when we add real-time lead sync
  }

  /// Handle errors
  void _handleError(dynamic error) {
    print('[WebSocket] Error: $error');
    _lastError.value = error.toString();
    _connectionStatus.value = 'Error';
    _scheduleReconnect();
  }

  /// Handle disconnect
  void _handleDisconnect() {
    print('[WebSocket] Disconnected from server');
    _disconnect();
    _scheduleReconnect();
  }

  /// Internal disconnect method
  void _disconnect() {
    _isConnected.value = false;
    _isConnecting.value = false;
    _connectionStatus.value = 'Disconnected';

    _stopHeartbeat();

    try {
      _socket?.disconnect();
    } catch (_) {}
    _socket = null;
  }

  /// Start heartbeat system
  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: _heartbeatInterval),
      (_) => _sendPing(),
    );

    print('[WebSocket] Heartbeat started (${_heartbeatInterval}ms interval)');
  }

  /// Stop heartbeat system
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts.value >= _maxReconnectAttempts) {
      print('[WebSocket] Max reconnection attempts reached');
      _connectionStatus.value = 'Max Reconnect Attempts';
      return;
    }

    if (_isConnected.value || _isConnecting.value) {
      return;
    }

    _reconnectAttempts.value++;
    _connectionStatus.value =
        'Reconnecting... (${_reconnectAttempts.value}/$_maxReconnectAttempts)';

    _reconnectTimer = Timer(
      const Duration(milliseconds: _reconnectDelay),
      () => connect(),
    );

    print(
      '[WebSocket] Reconnection scheduled in ${_reconnectDelay}ms (attempt ${_reconnectAttempts.value})',
    );
  }

  // _waitForConnection removed (unused)

  /// Get authentication token
  Future<String?> _getAuthToken() async {
    try {
      if (Get.isRegistered<AuthService>()) {
        final token = AuthService.instance.accessToken;
        if (token.isEmpty) {
          print('[WebSocket] _getAuthToken: empty');
          return null;
        }
        print('[WebSocket] _getAuthToken: present (${token.length} chars)');
        return token;
      }
      return null;
    } catch (e) {
      print('[WebSocket] Error getting auth token: $e');
      return null;
    }
  }

  /// Get server URL
  Future<String?> _getServerUrl() async {
    try {
      // Point to your backend socket.io origin (no /v1)
      // Use the same IP as the API service
      return Config.webSocketUrl;
    } catch (e) {
      print('[WebSocket] Error getting server URL: $e');
      return null;
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected.value,
      'isConnecting': _isConnecting.value,
      'connectionStatus': _connectionStatus.value,
      'reconnectAttempts': _reconnectAttempts.value,
      'lastError': _lastError.value,
      'serverTime': _serverTime.value,
      'latency': _latency.value,
      'lastPingTime': _lastPingTime?.toIso8601String(),
      'lastPongTime': _lastPongTime?.toIso8601String(),
    };
  }

  /// Force reconnection
  void forceReconnect() {
    _reconnectAttempts.value = 0;
    _disconnect();
    _scheduleReconnect();
  }

  @override
  void onClose() {
    _disconnect();
    _reconnectTimer?.cancel();
    super.onClose();
  }
}
