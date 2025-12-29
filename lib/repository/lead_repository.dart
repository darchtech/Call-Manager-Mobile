import 'package:hive_flutter/hive_flutter.dart';
import '../model/lead.dart';

class LeadRepository {
  static const String _leadBoxName = 'leads';
  static const String _statusOptionsBoxName = 'status_options';

  static Box<Lead>? _leadBox;
  static Box<LeadStatus>? _statusOptionsBox;

  static LeadRepository? _instance;

  LeadRepository._();

  static LeadRepository get instance {
    _instance ??= LeadRepository._();
    return _instance!;
  }

  /// Initialize Hive database for leads
  static Future<void> initialize() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(LeadAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(LeadStatusAdapter());
    }

    // Open boxes with error handling for schema migration
    try {
      _leadBox = await Hive.openBox<Lead>(_leadBoxName);
    } catch (e) {
      // If opening fails (likely due to schema mismatch), delete and recreate
      print('[LeadRepo] Error opening lead box (schema mismatch?): $e');
      print('[LeadRepo] Deleting old lead box and recreating with new schema...');
      try {
        // Close if it was partially opened
        await _leadBox?.close();
      } catch (_) {}
      // Delete the box file
      await Hive.deleteBoxFromDisk(_leadBoxName);
      // Reopen with new schema
    _leadBox = await Hive.openBox<Lead>(_leadBoxName);
      print('[LeadRepo] Lead box recreated with new schema');
    }

    try {
      _statusOptionsBox = await Hive.openBox<LeadStatus>(_statusOptionsBoxName);
    } catch (e) {
      // If opening fails, delete and recreate
      print('[LeadRepo] Error opening status options box: $e');
      print('[LeadRepo] Deleting old status options box and recreating...');
      try {
        await _statusOptionsBox?.close();
      } catch (_) {}
      await Hive.deleteBoxFromDisk(_statusOptionsBoxName);
    _statusOptionsBox = await Hive.openBox<LeadStatus>(_statusOptionsBoxName);
      print('[LeadRepo] Status options box recreated');
    }

    print(
      '[LeadRepo] Database initialized with ${_leadBox!.length} leads and ${_statusOptionsBox!.length} status options',
    );
  }

  /// Get leads box
  Box<Lead> get leadBox {
    if (_leadBox == null || !_leadBox!.isOpen) {
      throw Exception(
        'Lead database not initialized. Call initialize() first.',
      );
    }
    return _leadBox!;
  }

  /// Get status options box
  Box<LeadStatus> get statusOptionsBox {
    if (_statusOptionsBox == null || !_statusOptionsBox!.isOpen) {
      throw Exception(
        'Status options database not initialized. Call initialize() first.',
      );
    }
    return _statusOptionsBox!;
  }

  // ========== LEAD OPERATIONS ==========

  /// Save a lead
  Future<void> saveLead(Lead lead) async {
    try {
      final payload = lead.toJson();
      print('[LeadRepo] Saving lead payload: ' + payload.toString());
      await leadBox.put(lead.id, lead);
      print('[LeadRepo] Saved lead: ${lead.id} - ${lead.firstName} ${lead.lastName}');
    } catch (e) {
      print('[LeadRepo] Error saving lead: $e');
      rethrow;
    }
  }

  /// Get a lead by ID
  Lead? getLead(String id) {
    print('[REPO-LeadRepository] 🔍 Getting lead by ID: $id');
    final lead = leadBox.get(id);
    if (lead != null) {
      print('[REPO-LeadRepository] ✅ Lead found: ${lead.firstName} ${lead.lastName} (${lead.id})');
    } else {
      print('[REPO-LeadRepository] ❌ Lead not found: $id');
    }
    return lead;
  }

  /// Get all leads
  List<Lead> getAllLeads() {
    return leadBox.values.toList();
  }

  /// Get leads with pagination and filtering
  List<Lead> getLeads({
    int? limit,
    int? offset,
    String? status,
    String? callStatus,
    String? searchQuery,
    bool sortByNewest = true,
  }) {
    var leads = leadBox.values.toList();

    // Apply filters
    if (status != null) {
      leads = leads.where((lead) => lead.status == status).toList();
    }
    if (callStatus != null) {
      leads = leads.where((lead) => lead.callStatus == callStatus).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      leads = leads
          .where(
            (lead) =>
                lead.firstName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                lead.lastName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                lead.phoneNumber.contains(searchQuery) ||
                (lead.email?.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (lead.company?.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    // Sort by updated time
    leads.sort((a, b) {
      final comparison = a.updatedAt.compareTo(b.updatedAt);
      return sortByNewest ? -comparison : comparison;
    });

    // Apply pagination
    if (offset != null) {
      leads = leads.skip(offset).toList();
    }
    if (limit != null) {
      leads = leads.take(limit).toList();
    }

    return leads;
  }

  /// Get leads by phone number
  List<Lead> getLeadsByPhoneNumber(String phoneNumber) {
    // Extract last 10 digits from the search phone number
    final searchDigits =
        phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 10
        ? phoneNumber
              .replaceAll(RegExp(r'[^\d]'), '')
              .substring(
                phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length - 10,
              )
        : phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    return leadBox.values.where((lead) {
      // Extract last 10 digits from stored phone number
      final storedDigits =
          lead.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 10
          ? lead.phoneNumber
                .replaceAll(RegExp(r'[^\d]'), '')
                .substring(
                  lead.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length - 10,
                )
          : lead.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      return storedDigits == searchDigits;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get unsynced leads
  List<Lead> getUnsyncedLeads() {
    return leadBox.values.where((lead) => !lead.isSynced).toList()..sort(
      (a, b) => a.updatedAt.compareTo(b.updatedAt),
    ); // Oldest first for sync
  }

  /// Get leads that need follow-up
  List<Lead> getLeadsNeedingFollowUp() {
    return leadBox.values.where((lead) => lead.needsFollowUp).toList()..sort(
      (a, b) =>
          a.lastContactedAt?.compareTo(b.lastContactedAt ?? DateTime(1970)) ??
          0,
    );
  }

  /// Update a lead
  Future<void> updateLead(Lead lead) async {
    try {
      lead.updatedAt = DateTime.now();
      final payload = lead.toJson();
      print('[LeadRepo] Updating lead payload: ' + payload.toString());
      await leadBox.put(lead.id, lead);
      print('[LeadRepo] Updated lead: ${lead.id}');
    } catch (e) {
      print('[LeadRepo] Error updating lead: $e');
      rethrow;
    }
  }

  /// Delete a lead
  Future<void> deleteLead(String id) async {
    try {
      await leadBox.delete(id);
      print('[LeadRepo] Deleted lead: $id');
    } catch (e) {
      print('[LeadRepo] Error deleting lead: $e');
      rethrow;
    }
  }

  /// Mark lead as synced
  Future<void> markLeadSynced(String id, {String? error}) async {
    final lead = getLead(id);
    if (lead != null) {
      lead.markSynced(error: error);
      await updateLead(lead);
    }
  }

  /// Get lead statistics
  Map<String, dynamic> getLeadStatistics() {
    final leads = getAllLeads();

    final totalLeads = leads.length;
    final contactedLeads = leads.where((l) => l.status == 'Contacted').length;
    final notInterestedLeads = leads
        .where((l) => l.status == 'Not Interested')
        .length;
    final followUpLeads = leads.where((l) => l.status == 'Follow Up').length;
    final calledLeads = leads.where((l) => l.callStatus == 'Called').length;
    final missedLeads = leads.where((l) => l.callStatus == 'Missed').length;

    return {
      'totalLeads': totalLeads,
      'contactedLeads': contactedLeads,
      'notInterestedLeads': notInterestedLeads,
      'followUpLeads': followUpLeads,
      'calledLeads': calledLeads,
      'missedLeads': missedLeads,
      'unsyncedCount': getUnsyncedLeads().length,
      'needsFollowUpCount': getLeadsNeedingFollowUp().length,
    };
  }

  // ========== STATUS OPTIONS OPERATIONS ==========

  /// Save status option
  Future<void> saveStatusOption(LeadStatus option) async {
    try {
      await statusOptionsBox.put(option.id, option);
      print('[LeadRepo] Saved status option: ${option.id} - ${option.name}');
    } catch (e) {
      print('[LeadRepo] Error saving status option: $e');
      rethrow;
    }
  }

  /// Get all status options
  List<LeadStatus> getAllStatusOptions() {
    return statusOptionsBox.values.toList();
  }

  /// Get status options by type
  List<LeadStatus> getStatusOptionsByType(String type) {
    return statusOptionsBox.values
        .where((option) => option.type == type && option.isActive)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Get lead status options
  List<LeadStatus> getLeadStatusOptions() {
    return getStatusOptionsByType('leadStatus');
  }

  /// Get call status options
  List<LeadStatus> getCallStatusOptions() {
    return getStatusOptionsByType('callStatus');
  }

  /// Clear all status options (admin panel is source of truth)
  Future<void> clearAllStatusOptions() async {
    try {
      await statusOptionsBox.clear();
      print(
        '[LeadRepo] Cleared all status options - admin panel is source of truth',
      );
    } catch (e) {
      print('[LeadRepo] Error clearing status options: $e');
      rethrow;
    }
  }

  /// Force-insert Android call status labels locally, overriding server if needed
  Future<void> ensureAndroidCallStatusOptions() async {
    // Canonical Android outcome labels we use in CallController
    const List<String> androidLabels = <String>[
      'CALL_NO_ANSWER',
      'CALL_BUSY',
      'CALL_DECLINED_BY_LEAD',
      'CALL_CANCELLED_BY_CALLER',
      'CALL_ENDED_CONNECTED',
    ];

    // Build a quick lookup of existing callStatus names (case sensitive match)
    final existing = getStatusOptionsByType(
      'callStatus',
    ).map((o) => o.name).toSet();

    int orderBase = 1000; // Keep custom labels at the end
    for (int i = 0; i < androidLabels.length; i++) {
      final name = androidLabels[i];
      if (!existing.contains(name)) {
        final option = LeadStatus(
          name: name,
          type: 'callStatus',
          color: null,
          order: orderBase + i,
          isActive: true,
        );
        await saveStatusOption(option);
        print('[LeadRepo] Ensured Android call status option: ' + name);
      }
    }
  }

  /// Get unsynced status options
  List<LeadStatus> getUnsyncedStatusOptions() {
    return statusOptionsBox.values.where((option) => !option.isSynced).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Update status option
  Future<void> updateStatusOption(LeadStatus option) async {
    try {
      option.updatedAt = DateTime.now();
      await statusOptionsBox.put(option.id, option);
      print('[LeadRepo] Updated status option: ${option.id}');
    } catch (e) {
      print('[LeadRepo] Error updating status option: $e');
      rethrow;
    }
  }

  /// Mark status option as synced
  Future<void> markStatusOptionSynced(String id, {String? error}) async {
    final option = statusOptionsBox.get(id);
    if (option != null) {
      option.isSynced = error == null;
      option.syncedAt = error == null ? DateTime.now() : null;
      await updateStatusOption(option);
    }
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    try {
      await leadBox.clear();
      await statusOptionsBox.clear();
      print('[LeadRepo] Cleared all lead data');
    } catch (e) {
      print('[LeadRepo] Error clearing data: $e');
      rethrow;
    }
  }

  /// Get database info
  Map<String, dynamic> getDatabaseInfo() {
    return {
      'leadsCount': leadBox.length,
      'statusOptionsCount': statusOptionsBox.length,
      'leadBoxPath': leadBox.path,
      'statusOptionsBoxPath': statusOptionsBox.path,
      'isLeadBoxOpen': leadBox.isOpen,
      'isStatusOptionsBoxOpen': statusOptionsBox.isOpen,
    };
  }

  /// Close database connections
  Future<void> close() async {
    await _leadBox?.close();
    await _statusOptionsBox?.close();
    print('[LeadRepo] Database connections closed');
  }
}
