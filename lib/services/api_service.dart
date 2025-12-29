import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../model/call_record.dart';
import '../model/lead.dart';
import '../model/task.dart';
import '../model/pagination_response.dart';
import '../utils/config.dart';
import 'auth_service.dart';

class ApiService extends GetxService {
  static ApiService get instance => Get.find<ApiService>();

  late Dio _dio;

  // Backend base URL (v1 router)
  static const String _baseUrl = Config.domainUrl;
  static const String _callRecordsEndpoint = '/call-records';
  static const String _leadsEndpoint = '/leads';
  static const String _tasksEndpoint = '/tasks';
  static const String _followUpsEndpoint = '/followups';
  // LeadStatus endpoints in backend
  static const String _statusOptionsEndpoint = '/lead-status';

  @override
  void onInit() {
    super.onInit();
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging and error handling
    _dio.interceptors.addAll([
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[API] $obj'),
      ),
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach access token if present
          final auth = Get.isRegistered<AuthService>()
              ? AuthService.instance
              : null;
          final token = auth?.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          print('[API] Error: ${error.message}');
          handler.next(error);
        },
      ),
    ]);

    // Refresh-token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            final req = e.requestOptions;
            try {
              final auth = Get.isRegistered<AuthService>()
                  ? AuthService.instance
                  : null;
              if (auth != null && await auth.refreshTokens()) {
                // Retry original request with new token
                final newToken = auth.accessToken;
                final opts = Options(
                  method: req.method,
                  headers: {
                    ...req.headers,
                    'Authorization': 'Bearer $newToken',
                  },
                  responseType: req.responseType,
                  contentType: req.contentType,
                  followRedirects: req.followRedirects,
                  listFormat: req.listFormat,
                  sendTimeout: req.sendTimeout,
                  receiveTimeout: req.receiveTimeout,
                );
                final cloneResponse = await _dio.request(
                  req.path,
                  options: opts,
                  data: req.data,
                  queryParameters: req.queryParameters,
                );
                return handler.resolve(cloneResponse);
              }
            } catch (_) {
              // fallthrough
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Sync a single call record to the server
  Future<ApiResponse<CallRecord>> syncCallRecord(CallRecord record) async {
    try {
      print('[API] Syncing call record: ${record.id}');

      // Map to backend schema
      final payload = {
        'phoneNumber': record.phoneNumber,
        'contactName': record.contactName,
        'initiatedAt': record.initiatedAt.toIso8601String(),
        'connectedAt': record.connectedAt?.toIso8601String(),
        'endedAt': record.endedAt?.toIso8601String(),
        'durationSeconds': record.durationSeconds,
        'status': record.status,
        'source': record.source.name,
        'isOutgoing': record.isOutgoing,
        'deviceInfo': record.deviceInfo,
        'metadata': record.metadata,
        'outcomeLabel': record.outcomeLabel,
        // leadId is optional; include if present in metadata
        'leadId': record.metadata != null
            ? (record.metadata!['leadId'] as String?)
            : null,
      }..removeWhere((k, v) => v == null);

      final response = await _dio.post(_callRecordsEndpoint, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        final syncedRecord = CallRecord.fromJson(
          Map<String, dynamic>.from(data),
        );
        return ApiResponse.success(syncedRecord);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Sync multiple call records in batch
  Future<ApiResponse<List<CallRecord>>> syncCallRecordsBatch(
    List<CallRecord> records,
  ) async {
    try {
      print('[API] Syncing batch of ${records.length} call records');

      // Current user id is required by backend syncUpload validation
      String? createdBy;
      if (Get.isRegistered<AuthService>()) {
        final auth = AuthService.instance;
        final user = auth.user;
        createdBy = (user?['_id'] ?? user?['id']) as String?;
      }

      final list = records.map((r) {
        return {
          'id': r.id,
          'phoneNumber': r.phoneNumber,
          'contactName': r.contactName,
          'initiatedAt': r.initiatedAt.toIso8601String(),
          'connectedAt': r.connectedAt?.toIso8601String(),
          'endedAt': r.endedAt?.toIso8601String(),
          'durationSeconds': r.durationSeconds,
          'status': r.status,
          'source': r.source.name,
          'isOutgoing': r.isOutgoing,
          'deviceInfo': r.deviceInfo,
          'metadata': r.metadata,
          'outcomeLabel': r.outcomeLabel,
          'leadId': r.metadata != null
              ? (r.metadata!['leadId'] as String?)
              : null,
          'createdBy': createdBy,
          'createdAt': r.initiatedAt.toIso8601String(),
          'updatedAt': (r.endedAt ?? r.connectedAt ?? r.initiatedAt)
              .toIso8601String(),
        }..removeWhere((k, v) => v == null);
      }).toList();

      final response = await _dio.post(
        '$_callRecordsEndpoint/sync/upload',
        data: {'callRecords': list},
      );

      if (response.statusCode == 200) {
        // Backend returns a result object; we treat success if 200
        // and echo back the input as synced for client purposes.
        final synced = records
            .map(
              (r) => CallRecord.fromJson({
                'id': r.id,
                'phoneNumber': r.phoneNumber,
                'contactName': r.contactName,
                'initiatedAt': r.initiatedAt.toIso8601String(),
                'connectedAt': r.connectedAt?.toIso8601String(),
                'endedAt': r.endedAt?.toIso8601String(),
                'duration': r.durationSeconds,
                'status': r.status,
                'source': r.source.name,
                'isOutgoing': r.isOutgoing,
                'deviceInfo': r.deviceInfo,
                'metadata': r.metadata,
              }),
            )
            .toList();
        return ApiResponse.success(synced);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Get call records from server
  Future<ApiResponse<List<CallRecord>>> getCallRecords({
    int? limit,
    int? offset,
    DateTime? since,
    String? phoneNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (since != null) queryParams['since'] = since.toIso8601String();
      if (phoneNumber != null) queryParams['phoneNumber'] = phoneNumber;

      final response = await _dio.get(
        _callRecordsEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['records'] ?? response.data;
        final records = data.map((json) => CallRecord.fromJson(json)).toList();
        return ApiResponse.success(records);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Update a call record on server
  Future<ApiResponse<CallRecord>> updateCallRecord(CallRecord record) async {
    try {
      print('[API] Updating call record: ${record.id}');

      final response = await _dio.put(
        '$_callRecordsEndpoint/${record.id}',
        data: record.toJson(),
      );

      if (response.statusCode == 200) {
        final updatedRecord = CallRecord.fromJson(response.data);
        return ApiResponse.success(updatedRecord);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Delete a call record from server
  Future<ApiResponse<void>> deleteCallRecord(String recordId) async {
    try {
      print('[API] Deleting call record: $recordId');

      final response = await _dio.delete('$_callRecordsEndpoint/$recordId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Check server health
  Future<ApiResponse<Map<String, dynamic>>> checkServerHealth() async {
    try {
      final response = await _dio.get('/health');

      if (response.statusCode == 200) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error('Server health check failed');
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ========== LEAD API METHODS ==========

  /// Get leads from server
  Future<ApiResponse<List<Lead>>> getLeads({
    int? limit,
    int? offset,
    String? status,
    String? callStatus,
    String? searchQuery,
    DateTime? since,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (status != null) queryParams['status'] = status;
      if (callStatus != null) queryParams['callStatus'] = callStatus;
      if (searchQuery != null) queryParams['search'] = searchQuery;
      if (since != null) queryParams['since'] = since.toIso8601String();

      final response = await _dio.get(
        _leadsEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        // Handle different server response structures
        List<dynamic> data;
        if (response.data['data'] != null &&
            response.data['data']['results'] != null) {
          // New server response structure
          data = response.data['data']['results'];
        } else if (response.data['leads'] != null) {
          // Old server response structure
          data = response.data['leads'];
        } else {
          // Direct array response
          data = response.data is List ? response.data : [];
        }

        final leads = data.map((json) => Lead.fromJson(json)).toList();
        return ApiResponse.success(leads);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ========== TASK API METHODS ==========

  Future<ApiResponse<List<Task>>> getMyTasks() async {
    try {
      final response = await _dio.get('$_tasksEndpoint/my');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        final tasks = data.map((json) => Task.fromJson(json)).toList();
        return ApiResponse.success(tasks);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<PaginationResponse<Task>>> getTasksPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
    String? sortBy,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status.toUpperCase();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sortBy'] = sortBy;
      }

      final response = await _dio.get(
        '$_tasksEndpoint',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final paginationData = PaginationResponse<Task>.fromJson(
          data,
          (json) => Task.fromJson(json),
        );
        return ApiResponse.success(paginationData);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> syncTaskProgress(
    List<Map<String, dynamic>> leadsData,
  ) async {
    try {
      print('[API] Syncing task progress for ${leadsData.length} leads');
      final response = await _dio.post(
        '$_tasksEndpoint/sync-progress',
        data: {'leads': leadsData},
      );
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ========== FOLLOW-UP API METHODS ==========

  Future<ApiResponse<void>> saveFcmToken(String token) async {
    try {
      final response = await _dio.post(
        '/users/me/fcm-token',
        data: {'fcmToken': token},
      );
      if (response.statusCode == 200) return ApiResponse.success(null);
      return ApiResponse.error('Failed to save FCM token');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getFollowUps({
    String? leadId,
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (leadId != null) query['leadId'] = leadId;
      if (status != null) query['status'] = status;

      // Increase limit to get more follow-ups (default is 20)
      query['limit'] = 100; // Get up to 100 follow-ups

      final response = await _dio.get(
        _followUpsEndpoint,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data =
            response.data['data']?['results'] ??
            response.data['data'] ??
            response.data;
        final list = (data as List)
            .cast<dynamic>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return ApiResponse.success(list);
      }
      return ApiResponse.error('Failed to fetch follow-ups');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createFollowUp({
    required String leadId,
    required DateTime dueAt,
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        _followUpsEndpoint,
        data: {
          'leadId': leadId,
          'dueAt': dueAt.toUtc().toIso8601String(),
          'note': note,
        },
      );
      if (response.statusCode == 201) {
        final data = Map<String, dynamic>.from(
          response.data['data'] ?? response.data,
        );
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Failed to create follow-up');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateFollowUp({
    required String followUpId,
    DateTime? dueAt,
    String? note,
    String? status,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (dueAt != null) payload['dueAt'] = dueAt.toUtc().toIso8601String();
      if (note != null) payload['note'] = note;
      if (status != null) payload['status'] = status;
      final response = await _dio.put(
        '$_followUpsEndpoint/$followUpId',
        data: payload,
      );
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          response.data['data'] ?? response.data,
        );
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Failed to update follow-up');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<void>> deleteFollowUp(String followUpId) async {
    try {
      final response = await _dio.delete('$_followUpsEndpoint/$followUpId');
      if (response.statusCode == 200 || response.statusCode == 204)
        return ApiResponse.success(null);
      return ApiResponse.error('Failed to delete follow-up');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resolveFollowUp({
    required String followUpId,
    required String resolutionReason,
    String resolutionType = 'RESOLVED',
  }) async {
    try {
      final response = await _dio.post(
        '$_followUpsEndpoint/$followUpId/resolve',
        data: {
          'resolutionReason': resolutionReason,
          'resolutionType': resolutionType,
        },
      );
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          response.data['data'] ?? response.data,
        );
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Failed to resolve follow-up');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> unresolveFollowUp(
    String followUpId,
  ) async {
    try {
      final response = await _dio.post(
        '$_followUpsEndpoint/$followUpId/unresolve',
      );
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          response.data['data'] ?? response.data,
        );
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Failed to unresolve follow-up');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getResolvedFollowUps({
    String? resolvedBy,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (resolvedBy != null) query['resolvedBy'] = resolvedBy;
      if (from != null) query['from'] = from.toIso8601String();
      if (to != null) query['to'] = to.toIso8601String();

      final response = await _dio.get(
        '$_followUpsEndpoint/resolved',
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data =
            response.data['data']?['results'] ??
            response.data['data'] ??
            response.data;
        final list = (data as List)
            .cast<dynamic>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return ApiResponse.success(list);
      }
      return ApiResponse.error('Failed to fetch resolved follow-ups');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ========== LEAD API METHODS ==========

  Future<ApiResponse<Lead>> getLeadById(String leadId) async {
    try {
      print('[API-SERVICE] 🔍 Fetching lead by ID: $leadId');
      final response = await _dio.get('$_leadsEndpoint/$leadId');
      print('[API-SERVICE] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final lead = Lead.fromJson(data);
        print(
          '[API-SERVICE] ✅ Lead fetched successfully: ${lead.firstName} ${lead.lastName}',
        );
        return ApiResponse.success(lead);
      } else {
        print('[API-SERVICE] ❌ Server returned status: ${response.statusCode}');
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('[API-SERVICE] ❌ DioException: ${_handleDioError(e)}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      print('[API-SERVICE] ❌ Unexpected error: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Sync a single lead to the server
  Future<ApiResponse<Lead>> syncLead(Lead lead) async {
    try {
      print('[API] Syncing lead: ${lead.id}');

      // Build payload for creation: exclude local-only fields like id, createdAt, updatedAt
      final createData = {
        'firstName': lead.firstName,
        'lastName': lead.lastName,
        'phoneNumber': lead.phoneNumber,
        'email': lead.email,
        'class': lead.class_,
        'city': lead.city,
        'status': lead.status,
        'remark': lead.remark,
        'callStatus': lead.callStatus,
        'lastContactedAt': lead.lastContactedAt?.toIso8601String(),
        'metadata': lead.metadata, // includes clientTempId if set
        'assignedTo': lead.assignedTo,
        'source': lead.source,
        'priority': lead.priority,
      }..removeWhere((k, v) => v == null);

      final response = await _dio.post(_leadsEndpoint, data: createData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = response.data['data'] ?? response.data;
        final syncedLead = Lead.fromJson(payload);
        return ApiResponse.success(syncedLead);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Update a lead on server
  Future<ApiResponse<Lead>> updateLead(Lead lead) async {
    try {
      print('[API] Updating lead: ${lead.id}');

      // Create update payload with only allowed fields that exist in Lead model
      final updateData = {
        'firstName': lead.firstName,
        'lastName': lead.lastName,
        'phoneNumber': lead.phoneNumber,
        'email': lead.email,
        'class': lead.class_,
        'city': lead.city,
        'status': lead.status,
        'remark': lead.remark,
        'callStatus': lead.callStatus,
        'lastContactedAt': lead.lastContactedAt?.toIso8601String(),
        'metadata': lead.metadata,
        'assignedTo': lead.assignedTo,
        'source': lead.source,
        'priority': lead.priority,
      };

      // Remove null values to avoid sending empty fields
      updateData.removeWhere((key, value) => value == null);

      final response = await _dio.patch(
        '$_leadsEndpoint/${lead.id}',
        data: updateData,
      );

      if (response.statusCode == 200) {
        final payload = response.data['data'] ?? response.data;
        final updatedLead = Lead.fromJson(payload);
        return ApiResponse.success(updatedLead);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Delete a lead from server
  Future<ApiResponse<void>> deleteLead(String leadId) async {
    try {
      print('[API] Deleting lead: $leadId');

      final response = await _dio.delete('$_leadsEndpoint/$leadId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Sync multiple leads in batch
  Future<ApiResponse<List<Lead>>> syncLeadsBatch(List<Lead> leads) async {
    // Disabled until backend endpoint exists
    return ApiResponse.error('Not implemented on server (/v1/leads/batch)');
    /*
    try {
      print('[API] Syncing batch of ${leads.length} leads');

      final response = await _dio.post(
        '$_leadsEndpoint/batch',
        data: {'leads': leads.map((l) => l.toJson()).toList()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data['leads'] ?? response.data;
        final syncedLeads = data.map((json) => Lead.fromJson(json)).toList();
        return ApiResponse.success(syncedLeads);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
    */
  }

  // ========== STATUS OPTIONS API METHODS ==========

  /// Get status options from server
  Future<ApiResponse<List<LeadStatus>>> getStatusOptions({String? type}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;

      final response = await _dio.get(
        _statusOptionsEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        // Handle different server response structures
        List<dynamic> data;
        if (response.data['data'] != null &&
            response.data['data']['results'] != null) {
          // New server response structure
          data = response.data['data']['results'];
        } else if (response.data['options'] != null) {
          // Old server response structure
          data = response.data['options'];
        } else {
          // Direct array response
          data = response.data is List ? response.data : [];
        }

        final options = data.map((json) => LeadStatus.fromJson(json)).toList();
        return ApiResponse.success(options);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ========== AUTH API METHODS ==========

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        return ApiResponse.success(Map<String, dynamic>.from(response.data));
      }
      return ApiResponse.error('Login failed');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> refreshTokens(
    String refreshToken,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      if (response.statusCode == 200) {
        return ApiResponse.success(
          Map<String, dynamic>.from(response.data['tokens'] ?? response.data),
        );
      }
      return ApiResponse.error('Refresh failed');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<void>> logout(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
      if (response.statusCode == 204) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error('Logout failed');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      if (response.statusCode == 200) {
        return ApiResponse.success(Map<String, dynamic>.from(response.data));
      }
      return ApiResponse.error('Fetch me failed');
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Sync status options to server
  Future<ApiResponse<List<LeadStatus>>> syncStatusOptions(
    List<LeadStatus> options,
  ) async {
    try {
      print('[API] Syncing ${options.length} status options');

      final response = await _dio.post(
        '$_statusOptionsEndpoint/batch',
        data: {'options': options.map((o) => o.toJson()).toList()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data['options'] ?? response.data;
        final syncedOptions = data
            .map((json) => LeadStatus.fromJson(json))
            .toList();
        return ApiResponse.success(syncedOptions);
      } else {
        return ApiResponse.error(
          'Server returned status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  /// Handle Dio errors
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode} - ${e.response?.statusMessage}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error - check internet connectivity';
      case DioExceptionType.badCertificate:
        return 'Bad certificate';
      case DioExceptionType.unknown:
        return 'Network error: ${e.message}';
    }
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(success: true, data: data);
  }

  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse._(success: false, error: error, statusCode: statusCode);
  }

  bool get isSuccess => success;
  bool get isError => !success;
}
