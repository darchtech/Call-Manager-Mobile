import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../binding/call_binding.dart';
import '../binding/lead_binding.dart';
import '../binding/task_binding.dart';
import '../view/after_call_screen.dart';
import '../view/call_screen.dart';
import '../view/call_records_screen.dart';
import '../view/lead_screen.dart';
import '../view/lead_detail_screen.dart';
import '../view/follow_up_screen.dart';
import '../view/task_screen.dart';
import '../view/task_detail_screen.dart';
import '../model/task.dart';
import '../model/lead.dart';
import '../view/websocket_test_screen.dart';
import '../view/login_screen.dart';
import '../routes/routes.dart';
import '../controller/app_controller.dart';

class AppPages {
  AppPages._();
  static const Transition transition = Transition.native;
  static String INITIAL_ROUTE = Get.find<AppController>().getInitialRoute();

  static final route = [
    GetPage(
      name: '/login',
      page: () => const LoginScreen(),
      transition: transition,
    ),
    GetPage(
      name: Routes.CALL_SCREEN,
      page: () => CallScreen(),
      transition: transition,
      binding: CallBinding(),
    ),
    GetPage(
      name: Routes.AFTER_CALL_SCREEN,
      page: () => const ActiveCallScreen(),
      transition: transition,
      binding: CallBinding(),
    ),
    GetPage(
      name: Routes.CALL_RECORDS_SCREEN,
      page: () => const CallRecordsScreen(),
      transition: transition,
      binding: CallBinding(),
    ),
    GetPage(
      name: Routes.LEAD_SCREEN,
      page: () => const LeadScreen(),
      transition: transition,
      binding: LeadBinding(),
    ),
    GetPage(
      name: Routes.TASK_SCREEN,
      page: () => const TaskScreen(),
      transition: transition,
      binding: TaskBinding(),
    ),
    GetPage(
      name: Routes.TASK_DETAIL_SCREEN,
      page: () {
        print(
          '[AppPages] TASK_DETAIL_SCREEN - Get.arguments: ${Get.arguments}',
        );
        final task = Get.arguments as Task?;
        if (task == null) {
          print('[AppPages] Task is null, showing error screen');
          return const Scaffold(
            body: Center(child: Text('Error: Task not found')),
          );
        }
        print('[AppPages] Task found: ${task.id} - ${task.title}');
        return TaskDetailScreen(task: task);
      },
      transition: transition,
      binding: CallBinding(),
    ),
    GetPage(
      name: Routes.LEAD_DETAIL_SCREEN,
      page: () {
        print(
          '[AppPages] LEAD_DETAIL_SCREEN - Get.arguments: ${Get.arguments}',
        );

        // Handle both old format (Lead) and new format (Map with lead, isFromCallScreen, and editMode)
        if (Get.arguments is Map<String, dynamic>) {
          final args = Get.arguments as Map<String, dynamic>;
          final lead = args['lead'] as Lead?;
          final isFromCallScreen = args['isFromCallScreen'] as bool? ?? false;
          final editMode = args['editMode'] as bool? ?? false;

          if (lead == null) {
            print(
              '[AppPages] Lead is null in map arguments, showing error screen',
            );
            return const Scaffold(
              body: Center(child: Text('Error: Lead not found')),
            );
          }
          print(
            '[AppPages] Lead found from call screen: ${lead.id} - ${lead.firstName} ${lead.lastName}, isFromCallScreen: $isFromCallScreen, editMode: $editMode',
          );
          return LeadDetailScreen(
            lead: lead,
            isFromCallScreen: isFromCallScreen,
            editMode: editMode,
          );
        } else {
          // Handle old format for backward compatibility
          final lead = Get.arguments as Lead?;
          if (lead == null) {
            print('[AppPages] Lead is null, showing error screen');
            return const Scaffold(
              body: Center(child: Text('Error: Lead not found')),
            );
          }
          print('[AppPages] Lead found: ${lead.id} - ${lead.firstName} ${lead.lastName}');
          return LeadDetailScreen(lead: lead, isFromCallScreen: false);
        }
      },
      transition: transition,
      binding: LeadBinding(),
    ),
    GetPage(
      name: Routes.FOLLOW_UP_SCREEN,
      page: () {
        final leadId = Get.arguments as String?;
        return FollowUpScreen(leadId: leadId);
      },
      transition: transition,
      binding: LeadBinding(),
    ),
    GetPage(
      name: '/websocket-test',
      page: () => const WebSocketTestScreen(),
      transition: transition,
    ),
  ];
}
