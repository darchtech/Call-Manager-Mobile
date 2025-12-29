import 'package:get/get.dart';
import '../controller/lead_controller.dart';
import '../repository/lead_repository.dart';
import '../services/lead_sync_service.dart';
import '../services/api_service.dart';
import '../services/network_service.dart';
import '../controller/call_controller.dart';

class LeadBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize repositories and services
    Get.lazyPut<LeadRepository>(() => LeadRepository.instance);
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<NetworkService>(() => NetworkService());
    Get.lazyPut<LeadSyncService>(() => LeadSyncService());

    // Initialize controller
    Get.lazyPut<LeadController>(() => LeadController());

    // Call Controller
    Get.lazyPut<CallController>(() => CallController());
  }
}
