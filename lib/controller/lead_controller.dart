import 'package:get/get.dart';
import '../model/lead.dart';
import '../repository/lead_repository.dart';
import '../services/lead_sync_service.dart';
import '../services/network_service.dart';
import 'task_controller.dart';

class LeadController extends GetxController {
  static LeadController get instance => Get.find<LeadController>();

  final LeadRepository _leadRepo = LeadRepository.instance;
  final LeadSyncService _syncService = LeadSyncService.instance;
  final NetworkService _networkService = NetworkService.instance;

  // Observable lists
  final RxList<Lead> _leads = <Lead>[].obs;
  final RxList<LeadStatus> _leadStatusOptions = <LeadStatus>[].obs;
  final RxList<LeadStatus> _callStatusOptions = <LeadStatus>[].obs;

  // Observable state
  final RxBool _isLoading = false.obs;
  final RxBool _isRefreshing = false.obs;
  final RxString _searchQuery = ''.obs;
  final RxString _selectedStatus = ''.obs;
  final RxString _selectedCallStatus = ''.obs;
  final RxString _sortBy = 'updatedAt'.obs;
  final RxBool _sortAscending = false.obs;

  // Getters
  List<Lead> get leads => _leads;
  List<LeadStatus> get leadStatusOptions => _leadStatusOptions;
  List<LeadStatus> get callStatusOptions => _callStatusOptions;
  bool get isLoading => _isLoading.value;
  bool get isRefreshing => _isRefreshing.value;
  String get searchQuery => _searchQuery.value;
  String get selectedStatus => _selectedStatus.value;
  String get selectedCallStatus => _selectedCallStatus.value;
  String get sortBy => _sortBy.value;
  bool get sortAscending => _sortAscending.value;

  // Filtered leads
  List<Lead> get filteredLeads {
    var filtered = _leads.toList();

    // Apply search filter
    if (_searchQuery.value.isNotEmpty) {
      filtered = filtered
          .where(
            (lead) =>
                lead.firstName.toLowerCase().contains(
                  _searchQuery.value.toLowerCase(),
                ) ||
                lead.lastName.toLowerCase().contains(
                  _searchQuery.value.toLowerCase(),
                ) ||
                lead.phoneNumber.contains(_searchQuery.value) ||
                (lead.email?.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    ) ??
                    false) ||
                (lead.company?.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    // Apply status filter
    if (_selectedStatus.value.isNotEmpty) {
      filtered = filtered
          .where((lead) => lead.status == _selectedStatus.value)
          .toList();
    }

    // Apply call status filter (supports raw or category names)
    if (_selectedCallStatus.value.isNotEmpty) {
      filtered = filtered.where((lead) {
        final sel = _selectedCallStatus.value.toUpperCase();
        final raw = lead.callStatus.toUpperCase();
        final cat = lead.callStatusCategory.toUpperCase();
        return raw == sel || cat == sel;
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy.value) {
        case 'name':
        case 'firstName':
          comparison = a.firstName.compareTo(b.firstName);
          if (comparison == 0) {
            comparison = a.lastName.compareTo(b.lastName);
          }
          break;
        case 'lastName':
          comparison = a.lastName.compareTo(b.lastName);
          if (comparison == 0) {
            comparison = a.firstName.compareTo(b.firstName);
          }
          break;
        case 'phoneNumber':
          comparison = a.phoneNumber.compareTo(b.phoneNumber);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'callStatus':
          comparison = a.callStatus.compareTo(b.callStatus);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'updatedAt':
        default:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      return _sortAscending.value ? comparison : -comparison;
    });

    return filtered;
  }

  // Statistics
  Map<String, dynamic> get statistics {
    return {
      'totalLeads': _leads.length,
      'filteredLeads': filteredLeads.length,
      'contactedLeads': _leads.where((l) => l.status == 'Contacted').length,
      'notInterestedLeads': _leads
          .where((l) => l.status == 'Not Interested')
          .length,
      'followUpLeads': _leads.where((l) => l.status == 'Follow Up').length,
      // Category-based counts
      'contactedLeadsByCall': _leads
          .where((l) => l.callStatusCategory == 'CONTACTED')
          .length,
      'calledLeads': _leads
          .where((l) => l.callStatusCategory == 'CALLED')
          .length,
      'noAnswerLeads': _leads
          .where((l) => l.callStatusCategory == 'NO ANSWER')
          .length,
      'notContactedLeads': _leads
          .where((l) => l.callStatusCategory == 'NOT CONTACTED')
          .length,
      'needsFollowUp': _leads.where((l) => l.needsFollowUp).length,
    };
  }

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  /// Load initial data
  Future<void> _loadInitialData() async {
    await loadLeads();
    await loadStatusOptions();

    // Trigger background sync if online
    if (_networkService.isConnected) {
      _syncService.syncAllData();
    }
  }

  /// Load leads from local database
  Future<void> loadLeads() async {
    try {
      _isLoading.value = true;
      _leads.value = _leadRepo.getAllLeads();
      print('[LeadController] Loaded ${_leads.length} leads');
    } catch (e) {
      print('[LeadController] Error loading leads: $e');
      Get.snackbar('Error', 'Failed to load leads: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load status options from local database
  Future<void> loadStatusOptions() async {
    try {
      _leadStatusOptions.value = _leadRepo.getLeadStatusOptions();
      _callStatusOptions.value = _leadRepo.getCallStatusOptions();
      print(
        '[LeadController] Loaded ${_leadStatusOptions.length} lead status options and ${_callStatusOptions.length} call status options',
      );
    } catch (e) {
      print('[LeadController] Error loading status options: $e');
    }
  }

  /// Refresh data from server
  Future<void> refreshData() async {
    try {
      _isRefreshing.value = true;

      if (_networkService.isConnected) {
        final result = await _syncService.syncAllData();
        if (result.success) {
          await loadLeads();
          await loadStatusOptions();
          // Get.snackbar('Success', 'Data refreshed successfully');
        } else {
          // Get.snackbar(
          //   'Warning',
          //   'Refresh completed with some issues: ${result.error}',
          // );
        }
      } else {
        await loadLeads();
        await loadStatusOptions();
        Get.snackbar('Info', 'Loaded cached data (offline)');
      }
    } catch (e) {
      print('[LeadController] Error refreshing data: $e');
      Get.snackbar('Error', 'Failed to refresh data: $e');
    } finally {
      _isRefreshing.value = false;
    }
  }

  /// Create a new lead
  Future<void> createLead({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? email,
    String? company,
    String? class_,
    String? city,
    String? status,
    String? remark,
    String? callStatus,
    String? assignedTo,
    String? source,
    int priority = 0,
  }) async {
    try {
      final lead = Lead(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        email: email,
        company: company,
        class_: class_,
        city: city,
        status: status ?? _leadStatusOptions.first.name,
        remark: remark,
        callStatus: callStatus ?? _callStatusOptions.first.name,
        assignedTo: assignedTo,
        source: source,
        priority: priority,
      );

      // Tag locally created lead with clientTempId for reconciliation after server create
      lead.metadata = (lead.metadata ?? <String, dynamic>{})
        ..putIfAbsent('clientTempId', () => lead.id);

      await _leadRepo.saveLead(lead);
      _leads.add(lead);

      // Try to sync immediately if online
      if (_networkService.isConnected) {
        _syncService.syncLeadImmediately(lead);
      }

      Get.snackbar('Success', 'Lead created successfully');
      print('[LeadController] Created lead: ${lead.id}');
    } catch (e) {
      print('[LeadController] Error creating lead: $e');
      Get.snackbar('Error', 'Failed to create lead: $e');
    }
  }

  /// Update lead status
  Future<void> updateLeadStatus(
    String leadId,
    String newStatus, {
    String? remark,
  }) async {
    try {
      final lead = _leads.firstWhere(
        (l) => l.id == leadId,
        orElse: () {
          final fallback = _leadRepo.getLead(leadId);
          if (fallback != null) {
            _leads.add(fallback);
          }
          return fallback ?? (throw Exception('Lead not found: $leadId'));
        },
      );

      print(
        '[LeadController] updateLeadStatus BEFORE: id=${lead.id} name=${lead.firstName} ${lead.lastName} status=${lead.status} callStatus=${lead.callStatus} updatedAt=${lead.updatedAt.toIso8601String()}',
      );

      lead.updateStatus(newStatus, remark: remark);

      await _leadRepo.updateLead(lead);

      // Try to sync immediately if online
      if (_networkService.isConnected) {
        _syncService.updateLeadOnServer(lead);
      }

      // Recalculate task completion based on updated lead data
      await _recalculateTaskCompletion(leadId);

      print(
        '[LeadController] updateLeadStatus AFTER: id=${lead.id} status=${lead.status} callStatus=${lead.callStatus} updatedAt=${lead.updatedAt.toIso8601String()}',
      );
    } catch (e) {
      print('[LeadController] Error updating lead status: $e');
      Get.snackbar('Error', 'Failed to update lead status: $e');
    }
  }

  /// Update call status
  Future<void> updateCallStatus(String leadId, String newCallStatus) async {
    try {
      final lead = _leads.firstWhere(
        (l) => l.id == leadId,
        orElse: () {
          final fallback = _leadRepo.getLead(leadId);
          if (fallback != null) {
            _leads.add(fallback);
          }
          return fallback ?? (throw Exception('Lead not found: $leadId'));
        },
      );

      print(
        '[LeadController] updateCallStatus BEFORE: id=${lead.id} name=${lead.firstName} ${lead.lastName} status=${lead.status} callStatus=${lead.callStatus} updatedAt=${lead.updatedAt.toIso8601String()}',
      );

      lead.updateCallStatus(newCallStatus);

      await _leadRepo.updateLead(lead);

      // Try to sync immediately if online
      if (_networkService.isConnected) {
        _syncService.updateLeadOnServer(lead);
      }

      // Recalculate task completion based on updated lead data
      await _recalculateTaskCompletion(leadId);

      Get.snackbar('Success', 'Call status updated');
      print(
        '[LeadController] updateCallStatus AFTER: id=${lead.id} status=${lead.status} callStatus=${lead.callStatus} updatedAt=${lead.updatedAt.toIso8601String()}',
      );
    } catch (e) {
      print('[LeadController] Error updating call status: $e');
      Get.snackbar('Error', 'Failed to update call status: $e');
    }
  }

  /// Update lead remark
  Future<void> updateLeadRemark(String leadId, String remark) async {
    try {
      final lead = _leads.firstWhere((l) => l.id == leadId);
      lead.updateRemark(remark);

      await _leadRepo.updateLead(lead);

      // Try to sync immediately if online
      if (_networkService.isConnected) {
        _syncService.updateLeadOnServer(lead);
      }

      // Recalculate task completion based on updated lead data
      await _recalculateTaskCompletion(leadId);

      print('[LeadController] Updated lead remark: $leadId');
    } catch (e) {
      print('[LeadController] Error updating lead remark: $e');
      Get.snackbar('Error', 'Failed to update remark: $e');
    }
  }

  /// Delete lead
  Future<void> deleteLead(String leadId) async {
    try {
      await _leadRepo.deleteLead(leadId);
      _leads.removeWhere((l) => l.id == leadId);

      // Try to delete from server if online
      if (_networkService.isConnected) {
        // Note: You might want to add a delete API call here
        // await _apiService.deleteLead(leadId);
      }

      Get.snackbar('Success', 'Lead deleted');
      print('[LeadController] Deleted lead: $leadId');
    } catch (e) {
      print('[LeadController] Error deleting lead: $e');
      Get.snackbar('Error', 'Failed to delete lead: $e');
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  /// Set status filter
  void setStatusFilter(String status) {
    _selectedStatus.value = status;
  }

  /// Set call status filter
  void setCallStatusFilter(String callStatus) {
    _selectedCallStatus.value = callStatus;
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery.value = '';
    _selectedStatus.value = '';
    _selectedCallStatus.value = '';
  }

  /// Recalculate task completion for a lead
  Future<void> _recalculateTaskCompletion(String leadId) async {
    try {
      if (Get.isRegistered<TaskController>()) {
        final taskController = Get.find<TaskController>();
        await taskController.recalculateTaskCompletionForLead(leadId);
        print(
          '[LeadController] ✅ Recalculated task completion for lead: $leadId',
        );
      }
    } catch (e) {
      print(
        '[LeadController] ❌ Error recalculating task completion for lead $leadId: $e',
      );
    }
  }

  /// Set sorting
  void setSorting(String sortBy, {bool ascending = false}) {
    _sortBy.value = sortBy;
    _sortAscending.value = ascending;
  }

  /// Get leads that need follow-up
  List<Lead> getLeadsNeedingFollowUp() {
    return _leads.where((lead) => lead.needsFollowUp).toList();
  }

  /// Get leads by status
  List<Lead> getLeadsByStatus(String status) {
    return _leads.where((lead) => lead.status == status).toList();
  }

  /// Get leads by call status
  List<Lead> getLeadsByCallStatus(String callStatus) {
    return _leads.where((lead) => lead.callStatus == callStatus).toList();
  }

  /// Get lead by ID
  Lead? getLeadById(String id) {
    try {
      return _leads.firstWhere((lead) => lead.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Force sync all data
  Future<void> forceSync() async {
    try {
      final result = await _syncService.manualSync();
      if (result.success) {
        await loadLeads();
        await loadStatusOptions();
        Get.snackbar('Success', 'Sync completed successfully');
      } else {
        Get.snackbar('Error', 'Sync failed: ${result.error}');
      }
    } catch (e) {
      print('[LeadController] Error during force sync: $e');
      Get.snackbar('Error', 'Sync failed: $e');
    }
  }
}
