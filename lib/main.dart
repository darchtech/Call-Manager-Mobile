import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import 'package:toastification/toastification.dart';

import '../../widgets/toastification.dart';
import 'binding/app_binding.dart';
import 'controller/app_controller.dart';
import 'controller/call_controller.dart';
import 'controller/lead_controller.dart';
import 'controller/task_controller.dart';
import 'model/lead.dart';
import 'routes/app_pages.dart';
import 'utils/config.dart';
import 'utils/theme_config.dart';
import 'services/call_database_service.dart';
import 'services/call_sync_service.dart';
import 'services/lead_sync_service.dart';
import 'services/follow_up_service.dart';
import 'services/network_service.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/auth_service.dart';
import 'repository/lead_repository.dart';
import 'repository/task_repository.dart';
import 'services/task_service.dart';
import 'services/task_sync_service.dart';
import 'services/fcm_service.dart';
import 'services/reminder_service.dart';
import 'repository/follow_up_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive databases
  await CallDatabaseService.initialize();
  await LeadRepository.initialize();
  await TaskRepository.initialize();
  await FollowUpRepository.initialize();

  // Initialize services
  Get.put(NetworkService());
  Get.put(ApiService());
  Get.put(AuthService());
  Get.put(WebSocketService());
  Get.put(TaskService());
  Get.put(TaskSyncService());

  // Initialize sync services
  Get.put(CallSyncService());
  Get.put(LeadSyncService());
  Get.put(FollowUpService());

  // Initialize FCM and reminder services
  await FCMService.instance.initialize();
  await ReminderService.instance.initialize();

  // Initialize controllers
  Get.put(CallController());
  Get.put(LeadController());
  Get.put(TaskController());
  // Defer sync services until after successful login

  // Wait for AuthService to load persisted data before determining initial route
  await Get.find<AuthService>().onInit();

  // Initialize AppController (now AuthService has loaded its data)
  Get.put(AppController());

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const MethodChannel _navChannel = MethodChannel('call_tracking_nav');
  static const MethodChannel _dialerRoleChannel = MethodChannel('dialer_role');

  bool _hasAttemptedDialerSetup = false;

  @override
  void initState() {
    super.initState();

    // Set up method call handlers first
    _setupMethodChannelHandlers();

    // Defer role request until after first frame and permissions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Give UI time to settle
      await _ensureDialerRole();
    });
  }

  void _setupMethodChannelHandlers() {
    // Listen for navigation from native
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final String route = call.arguments as String;
        if (route.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            print('[call_tracking_nav] Navigating to: $route');
            if (Get.currentRoute != route) {
              Get.offAllNamed(route);
            }
          });
        }
      } else if (call.method == 'navigateToWithParams') {
        final Map<String, dynamic> params = Map<String, dynamic>.from(
          call.arguments,
        );
        final String route = params['route'] as String;
        final String? phoneNumber = params['phoneNumber'] as String?;
        final bool? editMode = params['editMode'] as bool?;

        if (route.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            print(
              '[call_tracking_nav] Navigating to: $route with params: phoneNumber=$phoneNumber, editMode=$editMode',
            );

            if (route == '/leadDetail' && phoneNumber != null) {
              // Find lead by phone number and navigate with edit mode
              final leadController = Get.find<LeadController>();
              final leads = leadController.leads;

              // Extract last 10 digits from the phone number for comparison
              final searchDigits =
                  phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 10
                  ? phoneNumber
                        .replaceAll(RegExp(r'[^\d]'), '')
                        .substring(
                          phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length -
                              10,
                        )
                  : phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

              print(
                '[call_tracking_nav] Searching with last 10 digits: $searchDigits',
              );

              Lead? lead;
              try {
                lead = leads.firstWhere((lead) {
                // Extract last 10 digits from stored phone number
                final storedDigits =
                    lead.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >=
                        10
                    ? lead.phoneNumber
                          .replaceAll(RegExp(r'[^\d]'), '')
                          .substring(
                            lead.phoneNumber
                                    .replaceAll(RegExp(r'[^\d]'), '')
                                    .length -
                                10,
                          )
                    : lead.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

                return storedDigits == searchDigits;
              });
              } catch (e) {
                lead = null;
              }

              if (lead != null) {
                print(
                  '[call_tracking_nav] Found lead: ${lead.firstName} ${lead.lastName} (${lead.phoneNumber})',
                );

                // Wait a bit more for the app to be fully initialized
                await Future<void>.delayed(const Duration(milliseconds: 500));

                // Try to navigate with error handling
                try {
                  Get.offAllNamed(
                    '/leadDetail',
                    arguments: {
                      'lead': lead,
                      'isFromCallScreen': true, // Always true when coming from call screen
                      'editMode': editMode == true, // Separate editMode parameter
                    },
                  );
                  print(
                    '[call_tracking_nav] Successfully navigated to /leadDetail',
                  );
                } catch (e) {
                  print(
                    '[call_tracking_nav] Navigation error: $e, trying alternative approach',
                  );
                  try {
                    Get.toNamed(
                      '/leadDetail',
                      arguments: {
                        'lead': lead,
                        'isFromCallScreen': true, // Always true when coming from call screen
                        'editMode': editMode == true, // Separate editMode parameter
                      },
                    );
                    print(
                      '[call_tracking_nav] Successfully navigated using Get.toNamed',
                    );
                  } catch (e2) {
                    print(
                      '[call_tracking_nav] Both navigation methods failed: $e2',
                    );
                    Get.snackbar('Error', 'Failed to open lead details: $e2');
                  }
                }
              } else {
                print(
                  '[call_tracking_nav] Lead not found for phone number: $phoneNumber (searched with: $searchDigits)',
                );
                Get.snackbar(
                  'Error',
                  'Lead not found for phone number: $phoneNumber',
                );
              }
            } else {
              if (Get.currentRoute != route) {
                Get.offAllNamed(route);
              }
            }
          });
        }
      }
    });

    // Listen for dialer role results
    _dialerRoleChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDefaultDialerResult') {
        final bool isDefault = call.arguments as bool;
        print('[dialer_role] Default dialer result: $isDefault');
        if (isDefault) {
          _showToast('Successfully set as default dialer!', isSuccess: true);
        } else {
          _showToast(
            'Failed to set as default dialer. Some features may not work properly.',
            isSuccess: false,
          );
        }
      }
    });
  }

  void _showToast(String message, {required bool isSuccess}) {
    // You can implement your toast logic here using your ToastHelper
    print('[TOAST] $message');
  }

  /// Check dialer eligibility and log detailed information
  Future<void> _checkDialerEligibility() async {
    try {
      final String eligibilityInfo =
          await _dialerRoleChannel.invokeMethod('checkDialerEligibility')
              as String;
      print('[DIALER_ELIGIBILITY]\n$eligibilityInfo');
    } catch (e) {
      print('[DIALER_ELIGIBILITY] Error: $e');
    }
  }

  /// Ensure the app is set as default dialer
  Future<void> _ensureDialerRole() async {
    if (_hasAttemptedDialerSetup) {
      print('[dialer_role] Already attempted setup, skipping');
      return;
    }

    _hasAttemptedDialerSetup = true;

    try {
      print('[dialer_role] Starting dialer role setup...');

      // First, check and log detailed eligibility info
      await _checkDialerEligibility();

      // Check if we're already the default dialer
      final bool isDefault =
          await _dialerRoleChannel.invokeMethod('isDefaultDialer') as bool;

      print('[dialer_role] Current default status: $isDefault');

      if (!isDefault) {
        print('[dialer_role] Not default dialer, requesting role...');

        // Register phone account to improve eligibility
        try {
          await _dialerRoleChannel.invokeMethod('registerPhoneAccount');
          print('[dialer_role] Phone account registered');
        } catch (e) {
          print('[dialer_role] Phone account registration failed: $e');
        }

        // Wait a bit after phone account registration
        await Future.delayed(const Duration(milliseconds: 500));

        // This should show the "Set as Default Dialer" prompt
        final bool result =
            await _dialerRoleChannel.invokeMethod('requestDefaultDialer')
                as bool;

        print('[dialer_role] Request result: $result');

        if (!result) {
          print('[dialer_role] Request failed or was denied');
          // Show a message to the user about the importance of being default dialer
          _showDialerImportanceDialog();
        }
      } else {
        print('[dialer_role] Already default dialer');
      }

      // Request overlay permission for native call experience
      await _requestOverlayPermission();
    } catch (e) {
      print('[dialer_role] Default dialer setup failed: $e');
      // Don't show error for unsupported platforms, but log it
      if (e.toString().contains('MissingPluginException')) {
        print('[dialer_role] Plugin not available on this platform');
      } else {
        _showDialerImportanceDialog();
      }
    }
  }

  /// Request overlay permission for native call experience
  Future<void> _requestOverlayPermission() async {
    try {
      print('[overlay] Checking overlay permission...');
      final bool hasPermission =
          await _dialerRoleChannel.invokeMethod('checkOverlayPermission')
              as bool;
      print('[overlay] Overlay permission granted: $hasPermission');

      if (!hasPermission) {
        print('[overlay] Requesting overlay permission...');
        await _dialerRoleChannel.invokeMethod('requestOverlayPermission');
        print('[overlay] Overlay permission requested');
      }
    } catch (e) {
      print('[overlay] Overlay permission setup failed: $e');
    }
  }

  void _showDialerImportanceDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Get.context != null) {
        showDialog(
          context: Get.context!,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(
                'Default Dialer Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'This app needs to be set as your default dialer to track call states accurately. '
                'Please go to Settings > Apps & notifications > Default apps > Phone app and select this app.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    promptSetDefaultDialer();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Set as Default'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  /// Call this from any button to prompt user again
  Future<void> promptSetDefaultDialer() async {
    try {
      print('[dialer_role] Manual prompt for default dialer...');
      await _checkDialerEligibility(); // Log current status
      final bool result =
          await _dialerRoleChannel.invokeMethod('requestDefaultDialer') as bool;
      print('[dialer_role] Manual request result: $result');
    } catch (e) {
      print('[dialer_role] Failed to prompt default dialer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return ToastificationWrapper(
          child: GetMaterialApp(
            navigatorKey: ToastHelper.navigatorKey,
            title: Config.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeConfig.lightTheme(),
            initialRoute: AppPages.INITIAL_ROUTE,
            initialBinding: AppBinding(),
            getPages: AppPages.route,
          ),
        );
      },
    );
  }
}
