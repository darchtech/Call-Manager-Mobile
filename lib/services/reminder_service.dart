import 'dart:async';
import 'package:get/get.dart';
// removed unused lead import
import '../model/follow_up.dart';
import '../repository/lead_repository.dart';
import '../repository/follow_up_repository.dart';
import 'fcm_service.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Service for managing follow-up reminders with FCM integration
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  static ReminderService get instance => _instance;

  final LeadRepository _leadRepo = LeadRepository.instance;
  final FollowUpRepository _followRepo = FollowUpRepository.instance;
  final FCMService _fcmService = FCMService.instance;

  Timer? _reminderCheckTimer;
  final List<FollowUp> _scheduledReminders = [];

  /// Initialize reminder service
  Future<void> initialize() async {
    try {
      // Load existing scheduled reminders
      await _loadScheduledReminders();

      // Start periodic reminder check
      _startReminderCheck();

      print('[ReminderService] Initialized successfully');
    } catch (e) {
      print('[ReminderService] Error initializing: $e');
    }
  }

  /// Load scheduled reminders from database
  Future<void> _loadScheduledReminders() async {
    try {
      _scheduledReminders
        ..clear()
        ..addAll(_followRepo.pending());

      // Only fetch from API if user is authenticated
      final authService = Get.find<AuthService>();
      if (authService.isAuthenticated) {
        final api = ApiService.instance;
        final resp = await api.getFollowUps(status: 'PENDING');
        if (resp.isSuccess) {
          for (final m in resp.data!) {
            final f = FollowUp.fromJson(m);
            await _followRepo.save(f);
          }
          _scheduledReminders
            ..clear()
            ..addAll(_followRepo.pending());
        }
      } else {
        print('[ReminderService] Skipping API fetch - user not authenticated');
      }

      print(
        '[ReminderService] Loaded ${_scheduledReminders.length} scheduled reminders',
      );
    } catch (e) {
      print('[ReminderService] Error loading scheduled reminders: $e');
    }
  }

  /// Start periodic reminder check
  void _startReminderCheck() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = Timer.periodic(
      const Duration(minutes: 30), // Check every 30 minutes
      (_) => _checkAndSendReminders(),
    );
  }

  /// Check and send reminders
  Future<void> _checkAndSendReminders() async {
    try {
      final now = DateTime.now();
      final dueReminders = <FollowUp>[];

      for (final f in _scheduledReminders) {
        if (f.dueAt.isBefore(now)) {
          dueReminders.add(f);
        }
      }

      for (final f in dueReminders) {
        await _sendReminderNotification(f);
        await _markReminderAsSent(f);
      }

      if (dueReminders.isNotEmpty) {
        print('[ReminderService] Sent ${dueReminders.length} reminders');
      }
    } catch (e) {
      print('[ReminderService] Error checking reminders: $e');
    }
  }

  /// Send reminder notification
  Future<void> _sendReminderNotification(FollowUp f) async {
    try {
      final lead = _leadRepo.getLead(f.leadId);
      final leadName = lead != null ? '${lead.firstName} ${lead.lastName}'.trim() : 'Lead';
      await _fcmService.scheduleFollowUpReminder(
        leadId: f.leadId,
        leadName: leadName,
        reminderDate: f.dueAt,
        message: f.note ?? 'Follow up with $leadName',
      );

      print('[ReminderService] Sent reminder for lead: $leadName');
    } catch (e) {
      print('[ReminderService] Error sending reminder: $e');
    }
  }

  /// Mark reminder as sent
  Future<void> _markReminderAsSent(FollowUp f) async {
    try {
      final updated = f.copyWith(
        status: 'DONE',
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _followRepo.save(updated);
      _scheduledReminders.removeWhere((x) => x.id == f.id);

      print('[ReminderService] Marked reminder as sent: ${f.id}');
    } catch (e) {
      print('[ReminderService] Error marking reminder as sent: $e');
    }
  }

  /// Schedule follow-up reminder for a lead
  Future<void> scheduleFollowUpReminder({
    required String leadId,
    required DateTime followUpDate,
    String? message,
    int reminderIntervalDays = 7,
  }) async {
    try {
      // Only schedule FCM notification - follow-up creation is handled by FollowUpService
      final lead = _leadRepo.getLead(leadId);
      final leadName = lead != null ? '${lead.firstName} ${lead.lastName}'.trim() : 'Lead';
      await _fcmService.scheduleFollowUpReminder(
        leadId: leadId,
        leadName: leadName,
        reminderDate: followUpDate,
        message: message ?? 'Follow up with $leadName',
      );

      print(
        '[ReminderService] Scheduled FCM reminder for $leadName on $followUpDate',
      );
    } catch (e) {
      print('[ReminderService] Error scheduling FCM reminder: $e');
    }
  }

  /// Cancel follow-up reminder
  Future<void> cancelFollowUpReminder(String followUpId) async {
    try {
      final api = ApiService.instance;
      await api.deleteFollowUp(followUpId);
      await _followRepo.delete(followUpId);
      _scheduledReminders.removeWhere((f) => f.id == followUpId);
      await _fcmService.cancelFollowUpReminder(followUpId);
      print('[ReminderService] Cancelled follow-up: $followUpId');
    } catch (e) {
      print('[ReminderService] Error cancelling reminder: $e');
    }
  }

  /// Update follow-up reminder
  Future<void> updateFollowUpReminder({
    required String followUpId,
    required DateTime newFollowUpDate,
    String? newMessage,
  }) async {
    try {
      final api = ApiService.instance;
      await api.updateFollowUp(
        followUpId: followUpId,
        dueAt: newFollowUpDate,
        note: newMessage,
      );
      final existing = _scheduledReminders.firstWhereOrNull(
        (f) => f.id == followUpId,
      );
      if (existing != null) {
        final updated = existing.copyWith(
          dueAt: newFollowUpDate,
          note: newMessage,
          updatedAt: DateTime.now(),
        );
        await _followRepo.save(updated);
        // update scheduled cache
        final idx = _scheduledReminders.indexWhere((f) => f.id == followUpId);
        if (idx != -1) {
          _scheduledReminders[idx] = updated;
        }
      }
      print('[ReminderService] Updated follow-up: $followUpId');
    } catch (e) {
      print('[ReminderService] Error updating reminder: $e');
    }
  }

  /// Get leads with scheduled reminders
  List<FollowUp> getScheduledReminders() {
    return _scheduledReminders.toList();
  }

  /// Get leads with overdue reminders
  List<FollowUp> getOverdueReminders() {
    final now = DateTime.now();
    return _scheduledReminders.where((f) => f.dueAt.isBefore(now)).toList();
  }

  /// Get leads with upcoming reminders (next 24 hours)
  List<FollowUp> getUpcomingReminders() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return _scheduledReminders.where((f) {
      return f.dueAt.isAfter(now) && f.dueAt.isBefore(tomorrow);
    }).toList();
  }

  /// Reschedule all reminders (useful after app restart)
  Future<void> rescheduleAllReminders() async {
    try {
      await _loadScheduledReminders();

      for (final f in _scheduledReminders) {
        final lead = _leadRepo.getLead(f.leadId);
        final leadName = lead != null ? '${lead.firstName} ${lead.lastName}'.trim() : 'Lead';
        await _fcmService.scheduleFollowUpReminder(
          leadId: f.leadId,
          leadName: leadName,
          reminderDate: f.dueAt,
          message: f.note ?? 'Follow up with $leadName',
        );
      }

      print(
        '[ReminderService] Rescheduled ${_scheduledReminders.length} reminders',
      );
    } catch (e) {
      print('[ReminderService] Error rescheduling reminders: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _reminderCheckTimer?.cancel();
    _scheduledReminders.clear();
  }
}
