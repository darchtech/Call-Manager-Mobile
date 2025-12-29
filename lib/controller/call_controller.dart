import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../model/call_record.dart';
import '../services/call_database_service.dart';
import '../services/call_sync_service.dart';
import '../services/network_service.dart';
import '../repository/lead_repository.dart';
import '../controller/lead_controller.dart';
import '../controller/task_controller.dart';
import '../services/lead_sync_service.dart';
import '../routes/routes.dart';
import '../utils/app_colors_new.dart';

class CallController extends GetxController {
  final Rx<Duration> callDuration = Rx<Duration>(Duration.zero);
  final Rx<DateTime?> callStartTime = Rx<DateTime?>(null);
  final RxBool _hadConnectedCall = false.obs;

  // New call recording system
  final Rx<CallRecord?> currentCallRecord = Rx<CallRecord?>(null);
  final RxString currentCallLeadId =
      ''.obs; // leadId associated with current call
  String?
  _lastMappedOutcomeLabel; // track last mapped outcome to avoid overrides

  Timer? _callTimer;
  // Removed duplicate call initiation via repository to prevent double activity
  final CallDatabaseService _dbService = CallDatabaseService.instance;
  late final CallSyncService _syncService;

  // Native MethodChannel for call tracking
  static const MethodChannel _nativeChannel = MethodChannel('call_tracking');

  @override
  void onInit() {
    super.onInit();
    _syncService = CallSyncService.instance;
    // Removed CallHistory storage initialization
    _attachNativeCallbacks();
  }

  void _attachNativeCallbacks() {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onCallStateChanged') {
        final args = call.arguments as List?;
        final String state = (args != null && args.isNotEmpty)
            ? (args[0] as String)
            : '';
        final String phoneNumber = (args != null && args.length > 1)
            ? (args[1] as String? ?? 'Unknown')
            : 'Unknown';

        log('[native] onCallStateChanged state=$state number=$phoneNumber');

        // Ignore state changes if we're not tracking this call,
        // EXCEPT: allow final outcomes to close the active-call banner robustly.
        if (currentCallRecord.value != null &&
            currentCallRecord.value!.phoneNumber != phoneNumber) {
          // If this is a final outcome, query native if any active call exists.
          if (isFinalOutcome(state)) {
            try {
              final bool hasActive =
                  await _nativeChannel.invokeMethod('hasActiveCall') as bool;
              if (!hasActive) {
                log(
                    '[native] Final state "$state" received for different number. No active calls detected natively — ending tracking.');
                _endCallTracking();
                _closeActiveCallScreenIfVisible();
              } else {
                log(
                    '[native] Final state "$state" received but native reports active calls. Keeping tracking.');
              }
            } catch (e) {
              log(
                  '[native] Error checking active call on final state: $e. Falling back to ignore.');
            }
          } else {
            log(
              '[native] Ignoring state change for different number: $phoneNumber vs ${currentCallRecord.value!.phoneNumber}',
            );
          }
          return;
        }

        if (state == 'CALL_DIALING' || state == 'CALL_CONNECTING') {
          // Only start tracking if we're not already tracking a call
          if (callStartTime.value == null) {
            _startCallTracking(
              phoneNumber,
              isOutgoing: state == 'CALL_DIALING',
            );
          }
          _updateCallRecordStatus(state);
        } else if (state == 'CALL_RINGING') {
          if (callStartTime.value == null) {
            _startCallTracking(phoneNumber, isOutgoing: false);
          } else {
            // Call already started, but number might have been updated (e.g., from retry)
            // Update phone number if it's no longer "Unknown" and current record has "Unknown"
            if (currentCallRecord.value != null &&
                currentCallRecord.value!.phoneNumber == 'Unknown' &&
                phoneNumber != 'Unknown') {
              log(
                '[CallController] Updating phone number from Unknown to: $phoneNumber',
              );
              currentCallRecord.value!.phoneNumber = phoneNumber;
              currentCallRecord.value!.contactName = _getContactName(
                phoneNumber,
              );
              _saveCallRecord(currentCallRecord.value!);
            }
          }
          _updateCallRecordStatus(state);
        } else if (state == 'CALL_INCOMING') {
          // Regular incoming call
          if (callStartTime.value == null) {
            _startCallTracking(phoneNumber, isOutgoing: false);
          }
          _updateCallRecordStatus('CALL_RINGING');
        } else if (state == 'CALL_WAITING_INCOMING') {
          // Call waiting - incoming call during active call
          log('[CallWaiting] Incoming call during active call: $phoneNumber');
          // Show call waiting notification in Flutter
          _showCallWaitingNotification(phoneNumber);
        } else if (state == 'CALL_ACTIVE') {
          // Call became active (could be from call waiting or hold)
          _hadConnectedCall.value = true;
          _updateCallRecordStatus(state);
        } else if (state == 'CALL_SWITCHED') {
          // Switched to another call
          log('[CallSwitch] Switched to call: $phoneNumber');
          _updateCallRecordStatus('CALL_CONNECTED');
        } else if (state == 'CALL_CONNECTED') {
          // Call is now active - just mark it but don't end tracking
          _hadConnectedCall.value = true;
          _updateCallRecordStatus(state);
          // Stay on the current screen, don't navigate
        } else if (state == 'CALL_ENDED_CONNECTED') {
          // Successful call - update to ended status and update lead
          _updateCallRecordStatus(state);
          final mapped = _mapAndroidOutcomeLabel(state);
          if (!_shouldSkipOutcome(mapped)) {
            _lastMappedOutcomeLabel = mapped;
            await _updateLeadAndTasksForOutcome(phoneNumber, mapped);
          }
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
          // Removed auto-navigation to CALL_SCREEN to avoid double back and route jumps
        } else if (state == 'CALL_ENDED_BY_CALLER' ||
            state == 'CALL_ENDED_BY_CALLEE') {
          // Precise connected-call end outcomes
          _updateCallRecordStatus(state);
          final mapped = _mapAndroidOutcomeLabel(state);
          if (!_shouldSkipOutcome(mapped)) {
            _lastMappedOutcomeLabel = mapped;
            await _updateLeadAndTasksForOutcome(phoneNumber, mapped);
          }
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
        } else if (state == 'CALL_ENDED_NO_ANSWER') {
          _updateCallRecordStatus(state);
          final mapped = _mapAndroidOutcomeLabel(state);
          if (!_shouldSkipOutcome(mapped)) {
            _lastMappedOutcomeLabel = mapped;
            await _updateLeadAndTasksForOutcome(phoneNumber, mapped);
          }
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
          // Removed auto-navigation to CALL_SCREEN to avoid double back and route jumps
        } else if (state == 'CALL_CANCELLED_BY_CALLER') {
          _updateCallRecordStatus(state);
          final mapped = _mapAndroidOutcomeLabel(state);
          if (!_shouldSkipOutcome(mapped)) {
            _lastMappedOutcomeLabel = mapped;
            await _updateLeadAndTasksForOutcome(phoneNumber, mapped);
          }
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
        } else if (state == 'CALL_DECLINED_BY_LEAD' ||
            state == 'CALL_DECLINED_BY_CALLEE' ||
            state == 'CALL_DECLINED_BY_CALLER') {
          _updateCallRecordStatus(state);
          await _updateLeadAndTasksForOutcome(
            phoneNumber,
            _mapAndroidOutcomeLabel(state),
          );
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
        } else if (state == 'CALL_BUSY') {
          _updateCallRecordStatus(state);
          await _updateLeadAndTasksForOutcome(
            phoneNumber,
            _mapAndroidOutcomeLabel(state),
          );
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
        } else if (state == 'CALL_NO_ANSWER') {
          _updateCallRecordStatus(state);
          final mapped = _mapAndroidOutcomeLabel(state);
          if (!_shouldSkipOutcome(mapped)) {
            _lastMappedOutcomeLabel = mapped;
            await _updateLeadAndTasksForOutcome(phoneNumber, mapped);
          }
          // Notify native UI to enter post-call mode
          if (isFinalOutcome(state)) {
            await _nativeChannel.invokeMethod('enterPostCallMode');
          }
          _endCallTracking();
          _closeActiveCallScreenIfVisible();
        }
      } else if (call.method == 'debugLog') {
        final msg = call.arguments as String?;
        if (msg != null) {
          log('[InCallService] $msg');
        }
      }
      return;
    });
  }

  Future<void> _updateLeadAndTasksForOutcome(
    String phoneNumber,
    String callStatusLabel,
  ) async {
    try {
      // Update lead by explicit leadId if available; fallback to phone lookup
      final leadRepo = LeadRepository.instance;
      String? targetLeadId = currentCallLeadId.value.isNotEmpty
          ? currentCallLeadId.value
          : null;
      var lead = targetLeadId != null ? leadRepo.getLead(targetLeadId) : null;
      if (lead == null) {
        final leads = leadRepo.getLeadsByPhoneNumber(phoneNumber);
        if (leads.isNotEmpty) {
          lead = leads.first;
          targetLeadId = lead.id;
        }
      }
      if (lead != null && targetLeadId != null) {
        log(
          '[CallOutcome] Updating lead $targetLeadId (${lead.phoneNumber}) callStatus -> "$callStatusLabel"',
        );
        if (Get.isRegistered<LeadController>()) {
          final leadController = LeadController.instance;
          await leadController.updateCallStatus(targetLeadId, callStatusLabel);
        } else {
          lead.updateCallStatus(callStatusLabel);
          await leadRepo.updateLead(lead);
          log(
            '[CallOutcome] Fallback persisted callStatus=${lead.callStatus} for lead $targetLeadId',
          );
        }
      }

      // Recalculate task completion based on lead completion status
      if (targetLeadId != null) {
        try {
          if (Get.isRegistered<TaskController>()) {
            final taskController = Get.find<TaskController>();
            await taskController.recalculateTaskCompletionForLead(targetLeadId);
          }
        } catch (e) {
          log('Error recalculating task completion: $e');
        }
      }

      // Trigger background sync if online
      try {
        final network = Get.find<NetworkService>();
        if (network.isConnected) {
          // LeadSyncService will pick up unsynced changes
          final leadSync = Get.find<LeadSyncService>();
          await leadSync.syncAllData();
        }
      } catch (_) {}
    } catch (e) {
      log('Error updating lead/task for outcome: $e');
    }
  }

  String _mapAndroidOutcomeLabel(String androidState) {
    // Standardize to Android-style labels for callStatus
    switch (androidState) {
      case 'CALL_CANCELLED_BY_CALLER':
        return 'CALL_CANCELLED_BY_CALLER';
      case 'CALL_DECLINED_BY_LEAD':
        return 'CALL_DECLINED_BY_LEAD';
      case 'CALL_DECLINED_BY_CALLEE':
        return 'CALL_DECLINED_BY_CALLEE';
      case 'CALL_DECLINED_BY_CALLER':
        return 'CALL_DECLINED_BY_CALLER';
      case 'CALL_BUSY':
        return 'CALL_BUSY';
      case 'CALL_NO_ANSWER':
        return 'CALL_NO_ANSWER';
      case 'CALL_ENDED_NO_ANSWER':
        return 'CALL_NO_ANSWER';
      case 'CALL_ENDED_BY_CALLER':
        return 'CALL_ENDED_BY_CALLER';
      case 'CALL_ENDED_BY_CALLEE':
        return 'CALL_ENDED_BY_CALLEE';
      case 'CALL_ENDED_CONNECTED':
        return 'CALLED'; // Map successful calls to "CALLED" status for leads
      case 'CALL_MISSED':
        return 'CALL_NO_ANSWER';
      default:
        return androidState; // Pass through for any other states
    }
  }

  // Avoid downgrading an already captured NO_ANSWER with CANCELLED_BY_CALLER
  bool _shouldSkipOutcome(String mapped) {
    // Do not downgrade NO_ANSWER -> CANCELLED_BY_CALLER
    if (mapped == 'CALL_CANCELLED_BY_CALLER' &&
        _lastMappedOutcomeLabel == 'CALL_NO_ANSWER') {
      return true;
    }
    // Once a call was CONTACTED (answered), don't let later local disconnects override it
    if (_lastMappedOutcomeLabel != null &&
        _isContactedLabel(_lastMappedOutcomeLabel!) &&
        !_isContactedLabel(mapped)) {
      return true;
    }
    return false;
  }

  bool _isContactedLabel(String label) {
    final s = label.toUpperCase();
    return s == 'CALLED' ||
        s == 'CALL_ENDED_CONNECTED' ||
        s == 'CALL_CONNECTED' ||
        s == 'CALL_ENDED_BY_CALLER' ||
        s == 'CALL_ENDED_BY_CALLEE';
  }

  bool isFinalOutcome(String status) {
    final s = status.toUpperCase();
    return s == 'CALL_DECLINED_BY_CALLEE' ||
        s == 'CALL_DECLINED_BY_LEAD' ||
        s == 'CALL_DECLINED_BY_CALLER' ||
        s == 'CALL_NO_ANSWER' ||
        s == 'CALL_BUSY' ||
        s == 'CALL_ENDED_BY_CALLER' ||
        s == 'CALL_ENDED_BY_CALLEE' ||
        s == 'CALL_ENDED_CONNECTED' ||
        s == 'CALL_ENDED_NO_ANSWER' ||
        s == 'CALL_CANCELLED_BY_CALLER';
  }

  // Removed CallHistory storage initialization

  void _startCallTracking(String phoneNumber, {bool isOutgoing = true}) {
    final now = DateTime.now();
    callStartTime.value = now;
    callDuration.value = Duration.zero;
    _lastMappedOutcomeLabel = null;

    // Create new call record for detailed tracking
    final metadata = {'appVersion': '1.0.0', 'platform': 'android'};

    // Include leadId in metadata if available
    if (currentCallLeadId.value.isNotEmpty) {
      metadata['leadId'] = currentCallLeadId.value;
    }

    currentCallRecord.value = CallRecord(
      phoneNumber: phoneNumber,
      contactName: _getContactName(phoneNumber),
      initiatedAt: now,
      status: isOutgoing ? 'CALL_DIALING' : 'CALL_RINGING',
      source: CallSource.app, // Calls from our app
      isOutgoing: isOutgoing,
      deviceInfo: _getDeviceInfo(),
      metadata: metadata,
    );

    // Save initial call record
    _saveCallRecord(currentCallRecord.value!);

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (callStartTime.value != null) {
        callDuration.value = DateTime.now().difference(callStartTime.value!);

        // Update call record duration in real-time for connected calls
        if (currentCallRecord.value != null &&
            (currentCallRecord.value!.status == 'CALL_CONNECTED' ||
                currentCallRecord.value!.status == 'CALL_ACTIVE')) {
          currentCallRecord.value!.calculateDuration();
          _saveCallRecord(currentCallRecord.value!);
        }
      }
    });

    _hadConnectedCall.value = true;
    log('[CallRecord] Started tracking call: ${currentCallRecord.value!.id}');

    // Notify listeners that call data has changed
    update();
  }

  void _endCallTracking() {
    _callTimer?.cancel();
    _callTimer = null;
    _lastMappedOutcomeLabel = null;

    // Removed legacy CallHistory handling

    // Finalize call record
    if (currentCallRecord.value != null) {
      currentCallRecord.value!.endedAt = DateTime.now();
      currentCallRecord.value!.calculateDuration();
      _saveCallRecord(currentCallRecord.value!);

      log(
        '[CallRecord] Ended tracking call: ${currentCallRecord.value!.id} - Duration: ${currentCallRecord.value!.formattedDuration}',
      );

      // Trigger sync for completed call
      final networkService = NetworkService.instance;
      networkService.executeWhenConnected(() {
        _syncService.forceSyncRecord(currentCallRecord.value!);
      });
    }

    callStartTime.value = null;
    callDuration.value = Duration.zero;
    currentCallRecord.value = null;

    // Notify listeners that call data has changed
    update();
  }
  // Removed CallHistory persistence methods

  Future<void> startCall(String phoneNumber) async {
    try {
      final bool granted =
          await _nativeChannel.invokeMethod('checkPermissions') as bool;
      if (!granted) {
        Get.snackbar(
          'Permission required',
          'Enable Phone permission in Settings',
        );
      }
    } catch (_) {}

    try {
      await _nativeChannel.invokeMethod('startPhoneCall', {
        'phoneNumber': phoneNumber,
      });
    } catch (_) {}
    // Remove duplicate trigger via repository to avoid double activity
  }

  /// Begin an app-initiated call and associate it with a specific leadId
  Future<void> startCallForLead({
    required String leadId,
    required String phoneNumber,
  }) async {
    currentCallLeadId.value = leadId;
    await startCall(phoneNumber);
  }

  // Helper methods for call recording
  void _updateCallRecordStatus(String status) {
    if (currentCallRecord.value != null) {
      currentCallRecord.value!.updateStatus(status);
      _saveCallRecord(currentCallRecord.value!);
      log(
        '[CallRecord] Updated status to: $status for call ${currentCallRecord.value!.id}',
      );
    }
  }

  Future<void> _saveCallRecord(CallRecord record) async {
    try {
      await _dbService.saveCallRecord(record);
    } catch (e) {
      log('[CallRecord] Error saving call record: $e');
    }
  }

  void _closeActiveCallScreenIfVisible() {
    try {
      // If the current route is the Active Call screen, pop it
      if (Get.currentRoute == Routes.AFTER_CALL_SCREEN) {
        Get.back();
        return;
      }
      // In case of stacked duplicates, ensure all Active Call screens are closed
      int safety = 0;
      while (Get.currentRoute == Routes.AFTER_CALL_SCREEN && safety < 3) {
        Get.back();
        safety++;
      }
    } catch (_) {}
  }

  String? _getContactName(String phoneNumber) {
    // TODO: Implement contact lookup
    // This could query the device's contacts to get the contact name
    return null;
  }

  String _getDeviceInfo() {
    // Basic device info - could be expanded
    return 'Android Device';
  }

  void _showCallWaitingNotification(String phoneNumber) {
    // Professional call waiting notification like WhatsApp/Telegram
    log('[CallWaiting] Showing call waiting notification for: $phoneNumber');

    // Show a prominent call waiting notification
    Get.snackbar(
      'Call Waiting',
      'Incoming call from $phoneNumber',
      duration: const Duration(seconds: 10), // Longer duration for call waiting
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      icon: const Icon(Icons.phone, color: Colors.white),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      isDismissible: false, // Don't allow dismissing call waiting
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
      animationDuration: const Duration(milliseconds: 300),
    );

    // TODO: In a full implementation, you could also:
    // 1. Show a dialog with "Answer" and "Decline" buttons
    // 2. Show an overlay similar to the active call screen
    // 3. Update the UI to show call waiting status
    // 4. Implement call hold/swap functionality
  }

  // API methods for accessing call records
  List<CallRecord> getAllCallRecords() {
    return _dbService.getAllCallRecords();
  }

  List<CallRecord> getCallRecordsByNumber(String phoneNumber) {
    return _dbService.getCallRecordsByNumber(phoneNumber);
  }

  Map<String, dynamic> getCallStatistics() {
    return _dbService.getCallStatistics();
  }

  Future<void> syncCallRecords() async {
    final result = await _syncService.manualSync();
    if (result.success) {
      Get.snackbar('Sync Complete', 'Call records synced successfully');
    } else {
      Get.snackbar('Sync Failed', result.error ?? 'Unknown error');
    }
  }

  /// Return to the active call screen (native Android activity)
  Future<bool> returnToCallScreen() async {
    try {
      final bool success =
          await _nativeChannel.invokeMethod('returnToCallScreen') as bool;
      return success;
    } catch (e) {
      log('[CallController] Error returning to call screen: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _callTimer?.cancel();
    super.onClose();
  }
}
