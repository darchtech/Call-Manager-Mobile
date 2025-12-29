import 'package:get/get.dart';

import '../routes/routes.dart';
import '../services/auth_service.dart';

class AppController extends GetxController {
  String getInitialRoute() {
    final authReady = Get.isRegistered<AuthService>();
    final authed = authReady ? AuthService.instance.isAuthenticated : false;
    print(
      '[AppController] AuthService ready: $authReady, Authenticated: $authed',
    );
    final route = authed ? Routes.TASK_SCREEN : '/login';
    print('[AppController] Initial route: $route');
    return route;
  }

  void navigateToLeads() {
    Get.toNamed(Routes.LEAD_SCREEN);
  }

  void navigateToCallScreen() {
    Get.toNamed(Routes.CALL_SCREEN);
  }

  void navigateToCallHistory() {
    Get.toNamed(Routes.CALL_HISTORY_SCREEN);
  }

  void navigateToCallRecords() {
    Get.toNamed(Routes.CALL_RECORDS_SCREEN);
  }
}
