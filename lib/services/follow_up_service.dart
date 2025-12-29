import 'package:get/get.dart';
import '../model/follow_up.dart';
import '../repository/lead_repository.dart';
import '../repository/follow_up_repository.dart';
import 'api_service.dart';
import 'fcm_service.dart';

class FollowUpService extends GetxService {
  static FollowUpService get instance => Get.find<FollowUpService>();

  final ApiService _apiService = Get.find<ApiService>();
  final LeadRepository _leadRepo = LeadRepository.instance;
  final FollowUpRepository _followRepo = FollowUpRepository.instance;
  final FCMService _fcmService = FCMService.instance;

  /// Get follow-ups for a specific lead
  Future<List<FollowUp>> getFollowUpsForLead(String leadId) async {
    try {
      print('[FollowUpService] 📋 Fetching follow-ups for lead: $leadId');

      final response = await _apiService.getFollowUps(leadId: leadId);

      if (response.isSuccess && response.data != null) {
        final followUps = (response.data as List)
            .map((json) => FollowUp.fromJson(json))
            .toList();

        print(
          '[FollowUpService] ✅ Found ${followUps.length} follow-ups for lead: $leadId',
        );
        return followUps;
      } else {
        print(
          '[FollowUpService] ❌ Failed to fetch follow-ups: ${response.error}',
        );
        return [];
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error fetching follow-ups: $e');
      return [];
    }
  }

  /// Create a new follow-up with FCM scheduling
  Future<FollowUp?> createFollowUp({
    required String leadId,
    required DateTime dueAt,
    String? note,
  }) async {
    try {
      print('[FollowUpService] 📝 Creating follow-up for lead: $leadId');
      print('[FollowUpService] - Due at: $dueAt');
      print('[FollowUpService] - Note: ${note ?? 'No note'}');

      // Create on server
      final response = await _apiService.createFollowUp(
        leadId: leadId,
        dueAt: dueAt,
        note: note,
      );

      FollowUp followUp;
      if (response.isSuccess && response.data != null) {
        followUp = FollowUp.fromJson(response.data!);
        print('[FollowUpService] ✅ Server follow-up created: ${followUp.id}');
      } else {
        // Create local fallback if server fails
        followUp = FollowUp(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          leadId: leadId,
          dueAt: dueAt,
          note: note,
          status: 'PENDING',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        print('[FollowUpService] ⚠️ Server failed, created local follow-up');
      }

      // Save to local repository
      await _followRepo.save(followUp);

      // Schedule FCM notification
      final lead = _leadRepo.getLead(leadId);
      final leadName = lead != null ? '${lead.firstName} ${lead.lastName}'.trim() : 'Lead';
      await _fcmService.scheduleFollowUpReminder(
        leadId: leadId,
        leadName: leadName,
        reminderDate: dueAt,
        message: note ?? 'Follow up with $leadName',
      );

      print('[FollowUpService] ✅ Follow-up created with FCM scheduling');
      return followUp;
    } catch (e) {
      print('[FollowUpService] ❌ Error creating follow-up: $e');
      return null;
    }
  }

  /// Update a follow-up
  Future<FollowUp?> updateFollowUp({
    required String followUpId,
    DateTime? dueAt,
    String? note,
    String? status,
  }) async {
    try {
      print('[FollowUpService] 📝 Updating follow-up: $followUpId');

      final response = await _apiService.updateFollowUp(
        followUpId: followUpId,
        dueAt: dueAt,
        note: note,
        status: status,
      );

      if (response.isSuccess && response.data != null) {
        final followUp = FollowUp.fromJson(response.data!);

        // Update local repository
        await _followRepo.save(followUp);

        print(
          '[FollowUpService] ✅ Follow-up updated successfully: ${followUp.id}',
        );
        print('[FollowUpService] - Updated dueAt: ${followUp.dueAt}');
        print('[FollowUpService] - Updated note: ${followUp.note}');
        return followUp;
      } else {
        print(
          '[FollowUpService] ❌ Failed to update follow-up: ${response.error}',
        );
        return null;
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error updating follow-up: $e');
      return null;
    }
  }

  /// Delete a follow-up
  Future<bool> deleteFollowUp(String followUpId) async {
    try {
      print('[FollowUpService] 🗑️ Deleting follow-up: $followUpId');

      final response = await _apiService.deleteFollowUp(followUpId);

      if (response.isSuccess) {
        print(
          '[FollowUpService] ✅ Follow-up deleted successfully: $followUpId',
        );
        return true;
      } else {
        print(
          '[FollowUpService] ❌ Failed to delete follow-up: ${response.error}',
        );
        return false;
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error deleting follow-up: $e');
      return false;
    }
  }

  /// Get all follow-ups
  Future<List<FollowUp>> getAllFollowUps({String? status}) async {
    try {
      print('[FollowUpService] 📋 Fetching all follow-ups');

      final response = await _apiService.getFollowUps(status: status);

      if (response.isSuccess && response.data != null) {
        final followUps = (response.data as List)
            .map((json) => FollowUp.fromJson(json))
            .toList();

        print('[FollowUpService] ✅ Found ${followUps.length} follow-ups');
        return followUps;
      } else {
        print(
          '[FollowUpService] ❌ Failed to fetch follow-ups: ${response.error}',
        );
        return [];
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error fetching follow-ups: $e');
      return [];
    }
  }

  /// Get local follow-ups (from repository)
  List<FollowUp> getLocalFollowUps({String? status}) {
    try {
      if (status != null) {
        return _followRepo.getAll().where((f) => f.status == status).toList();
      }
      return _followRepo.getAll();
    } catch (e) {
      print('[FollowUpService] ❌ Error getting local follow-ups: $e');
      return [];
    }
  }

  /// Get pending follow-ups (local)
  List<FollowUp> getPendingFollowUps() {
    return _followRepo.pending();
  }

  /// Get overdue follow-ups (local)
  List<FollowUp> getOverdueFollowUps() {
    final now = DateTime.now();
    return _followRepo
        .getAll()
        .where((f) => f.dueAt.isBefore(now) && f.status == 'PENDING')
        .toList();
  }

  /// Get upcoming follow-ups (next 24 hours)
  List<FollowUp> getUpcomingFollowUps() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return _followRepo
        .getAll()
        .where(
          (f) =>
              f.dueAt.isAfter(now) &&
              f.dueAt.isBefore(tomorrow) &&
              f.status == 'PENDING',
        )
        .toList();
  }

  /// Cancel follow-up and FCM notification
  Future<bool> cancelFollowUp(String followUpId) async {
    try {
      print('[FollowUpService] 🗑️ Cancelling follow-up: $followUpId');

      // Delete from server
      await _apiService.deleteFollowUp(followUpId);

      // Delete from local repository
      await _followRepo.delete(followUpId);

      // Cancel FCM notification
      await _fcmService.cancelFollowUpReminder(followUpId);

      print('[FollowUpService] ✅ Follow-up cancelled: $followUpId');
      return true;
    } catch (e) {
      print('[FollowUpService] ❌ Error cancelling follow-up: $e');
      return false;
    }
  }

  /// Mark follow-up as completed
  Future<bool> markFollowUpAsCompleted(String followUpId) async {
    try {
      print('[FollowUpService] ✅ Marking follow-up as completed: $followUpId');

      // Update on server
      await _apiService.updateFollowUp(followUpId: followUpId, status: 'DONE');

      // Update local repository
      final allFollowUps = _followRepo.getAll();
      final followUp = allFollowUps.firstWhere(
        (f) => f.id == followUpId,
        orElse: () => throw Exception('Follow-up not found'),
      );

      final updatedFollowUp = followUp.copyWith(
        status: 'DONE',
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _followRepo.save(updatedFollowUp);

      print('[FollowUpService] ✅ Follow-up marked as completed: $followUpId');
      return true;
    } catch (e) {
      print('[FollowUpService] ❌ Error marking follow-up as completed: $e');
      return false;
    }
  }

  /// Resolve follow-up (business logic)
  Future<bool> resolveFollowUp({
    required String followUpId,
    required String resolutionReason,
    String resolutionType = 'RESOLVED',
  }) async {
    try {
      print('[FollowUpService] 🔧 Resolving follow-up: $followUpId');

      final response = await _apiService.resolveFollowUp(
        followUpId: followUpId,
        resolutionReason: resolutionReason,
        resolutionType: resolutionType,
      );

      if (response.isSuccess && response.data != null) {
        final followUp = FollowUp.fromJson(response.data!);
        await _followRepo.save(followUp);
        print(
          '[FollowUpService] ✅ Follow-up resolved successfully: $followUpId',
        );
        return true;
      } else {
        print(
          '[FollowUpService] ❌ Failed to resolve follow-up: ${response.error}',
        );
        return false;
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error resolving follow-up: $e');
      return false;
    }
  }

  /// Unresolve follow-up (business logic)
  Future<bool> unresolveFollowUp(String followUpId) async {
    try {
      print('[FollowUpService] 🔄 Unresolving follow-up: $followUpId');

      final response = await _apiService.unresolveFollowUp(followUpId);

      if (response.isSuccess && response.data != null) {
        final followUp = FollowUp.fromJson(response.data!);
        await _followRepo.save(followUp);
        print(
          '[FollowUpService] ✅ Follow-up unresolved successfully: $followUpId',
        );
        return true;
      } else {
        print(
          '[FollowUpService] ❌ Failed to unresolve follow-up: ${response.error}',
        );
        return false;
      }
    } catch (e) {
      print('[FollowUpService] ❌ Error unresolving follow-up: $e');
      return false;
    }
  }

  /// Get resolved follow-ups (local)
  List<FollowUp> getResolvedFollowUps() {
    try {
      return _followRepo.getAll().where((f) => f.isResolved).toList();
    } catch (e) {
      print('[FollowUpService] ❌ Error getting resolved follow-ups: $e');
      return [];
    }
  }

  /// Get unresolved follow-ups (local)
  List<FollowUp> getUnresolvedFollowUps() {
    try {
      return _followRepo.getAll().where((f) => f.isUnresolved).toList();
    } catch (e) {
      print('[FollowUpService] ❌ Error getting unresolved follow-ups: $e');
      return [];
    }
  }
}
