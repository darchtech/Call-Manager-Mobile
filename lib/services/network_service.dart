import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class NetworkService extends GetxService {
  static NetworkService get instance => Get.find<NetworkService>();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final RxBool _isConnected = false.obs;
  final RxString _connectionType = 'none'.obs;
  final RxList<Function()> _pendingActions = <Function()>[].obs;

  bool get isConnected => _isConnected.value;
  String get connectionType => _connectionType.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeConnectivity();
    _startListening();
  }

  /// Initialize connectivity status
  Future<void> _initializeConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('[Network] Error checking initial connectivity: $e');
      _isConnected.value = false;
      _connectionType.value = 'none';
    }
  }

  /// Start listening to connectivity changes
  void _startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        print('[Network] Connectivity stream error: $error');
      },
    );
  }

  /// Update connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected.value;

    if (results.contains(ConnectivityResult.mobile)) {
      _isConnected.value = true;
      _connectionType.value = 'mobile';
    } else if (results.contains(ConnectivityResult.wifi)) {
      _isConnected.value = true;
      _connectionType.value = 'wifi';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      _isConnected.value = true;
      _connectionType.value = 'ethernet';
    } else {
      _isConnected.value = false;
      _connectionType.value = 'none';
    }

    print(
      '[Network] Connection status: ${_isConnected.value} (${_connectionType.value})',
    );

    // If connection restored, execute pending actions
    if (!wasConnected && _isConnected.value) {
      _executePendingActions();
    }
  }

  /// Add action to be executed when connection is restored
  void executeWhenConnected(Function() action) {
    if (_isConnected.value) {
      // Execute immediately if connected
      try {
        action();
      } catch (e) {
        print('[Network] Error executing immediate action: $e');
      }
    } else {
      // Queue for later execution
      _pendingActions.add(action);
      print(
        '[Network] Queued action for later execution (${_pendingActions.length} pending)',
      );
    }
  }

  /// Execute all pending actions
  void _executePendingActions() {
    if (_pendingActions.isEmpty) return;

    print('[Network] Executing ${_pendingActions.length} pending actions');

    final actionsToExecute = List<Function()>.from(_pendingActions);
    _pendingActions.clear();

    for (final action in actionsToExecute) {
      try {
        action();
      } catch (e) {
        print('[Network] Error executing pending action: $e');
      }
    }
  }

  /// Check if we have internet connectivity (not just network)
  Future<bool> hasInternetConnection() async {
    if (!_isConnected.value) return false;

    try {
      // You can implement a more sophisticated internet check here
      // For now, we assume network connectivity means internet connectivity
      return true;
    } catch (e) {
      print('[Network] Error checking internet connectivity: $e');
      return false;
    }
  }

  /// Wait for connection with timeout
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isConnected.value) return true;

    final completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = _isConnected.listen((isConnected) {
      if (isConnected) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    // Set timeout
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Get connection quality estimate
  String getConnectionQuality() {
    switch (_connectionType.value) {
      case 'wifi':
      case 'ethernet':
        return 'high';
      case 'mobile':
        return 'medium';
      default:
        return 'none';
    }
  }

  /// Get network info for logging
  Map<String, dynamic> getNetworkInfo() {
    return {
      'isConnected': _isConnected.value,
      'connectionType': _connectionType.value,
      'quality': getConnectionQuality(),
      'pendingActionsCount': _pendingActions.length,
    };
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
