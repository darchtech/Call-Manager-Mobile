import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../services/auth_service.dart';
import '../utils/app_colors_new.dart';
import '../services/network_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../routes/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // temporary password for testing
  final _password = 'Test@123';
  final _email = 'test@gmail.com';

  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  final _network = NetworkService.instance;
  final _ws = WebSocketService.instance;
  bool _healthOk = true;
  bool _checkingServer = false;
  String? _lastOverlayDebug; // to avoid spamming logs each build
  DateTime? _lastHealthAttempt;
  final Duration _healthRetryInterval = const Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    // _emailController.text = _email;
    // _passwordController.text = _password;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        final connected = _ws.isConnected; // retained for debug only
        final status = _ws.connectionStatus; // retained for debug only
        final online = _network.isConnected;

        final overlayDebug =
            'online=$online connected=$connected healthOk=$_healthOk checkingServer=$_checkingServer status="$status"';
        if (_lastOverlayDebug != overlayDebug) {
          _lastOverlayDebug = overlayDebug;
          // High-signal snapshot of gating state each time it changes
          // This helps diagnose why the overlay is shown
          // Example: [Login] overlayState: online=true connected=false healthOk=true ...
          // ignore: avoid_print
          print('[Login] overlayState: $overlayDebug');
        }

        return Stack(
          children: [
            // Background with gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.05),
                    AppColors.background,
                  ],
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 90.w,
                      maxHeight: 80.h,
                    ),
                    child: _buildLoginCard(),
                  ),
                ),
              ),
            ),

            // Overlay for connectivity issues
            if (!online || !_healthOk) _buildOverlay(),
          ],
        );
      }),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.white.withValues(alpha: 0.95)],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              _buildHeader(),
              SizedBox(height: 4.h),

              // Status banners
              if (!_network.isConnected)
                _buildBanner(
                  'No internet connection. Please connect to continue.',
                  AppColors.error,
                ),
              if (_network.isConnected && !_healthOk)
                _buildBanner(
                  'Server unavailable or under maintenance. Please try again later.',
                  AppColors.error,
                ),

              if (!_network.isConnected || !_healthOk) SizedBox(height: 2.h),

              // Form fields
              _buildEmailField(),
              SizedBox(height: 2.h),
              _buildPasswordField(),
              SizedBox(height: 2.h),

              // Error message
              if (_error != null) ...[
                _buildErrorMessage(),
                SizedBox(height: 2.h),
              ],

              // Login button
              _buildLoginButton(),
              SizedBox(height: 2.h),

              // Server status
              if (_checkingServer) _buildServerStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App logo/icon
        Container(
          width: 20.w,
          height: 20.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.phone_in_talk, color: Colors.white, size: 10.w),
        ),
        SizedBox(height: 3.h),

        // Welcome text
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 7.w,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Sign in to your account to continue',
          style: TextStyle(
            fontSize: 4.w,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(fontSize: 4.5.w),
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'Enter your email',
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 4.w),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 4.w,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: 4.5.w),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 4.w),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 4.w,
        ),
      ),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Password is required' : null,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 5.w),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 3.5.w,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _loading || !_network.isConnected || !_healthOk
              ? [AppColors.textSecondary, AppColors.textSecondary]
              : [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _loading || !_network.isConnected || !_healthOk
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _loading || !_network.isConnected || !_healthOk
            ? null
            : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Signing in...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 4.5.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildServerStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 4.w,
          height: 4.w,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(width: 2.w),
        Text(
          'Checking server...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 3.5.w),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _network.isConnected && _healthOk,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: (_network.isConnected && _healthOk) ? 0 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 15.w,
                      height: 15.w,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        !_network.isConnected ? Icons.wifi_off : Icons.build,
                        color: AppColors.error,
                        size: 8.w,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Title
                    Text(
                      !_network.isConnected
                          ? 'No Internet Connection'
                          : 'Server Maintenance',
                      style: TextStyle(
                        fontSize: 5.w,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),

                    // Message
                    Text(
                      !_network.isConnected
                          ? 'Please connect to the internet to continue.'
                          : 'Server is unavailable or under maintenance. Please try again later.',
                      style: TextStyle(
                        fontSize: 3.5.w,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 3.h),

                    // Loading indicator
                    SizedBox(
                      width: 6.w,
                      height: 6.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await AuthService.instance.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Get.offAllNamed(Routes.TASK_SCREEN);
    } else {
      setState(() => _error = 'Invalid credentials');
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareConnectivity();
  }

  Future<void> _prepareConnectivity() async {
    // ignore: avoid_print
    print('[Login] _prepareConnectivity: start');
    // Do not connect WebSocket pre-login; it will be rejected without a token

    setState(() => _checkingServer = true);
    final startedAt = DateTime.now();
    final health = await ApiService.instance.checkServerHealth();
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    // ignore: avoid_print
    print(
      '[Login] checkServerHealth: isSuccess=${health.isSuccess} elapsed=${elapsed}ms',
    );
    setState(() {
      _healthOk = health.isSuccess;
      _checkingServer = false;
    });

    // Schedule periodic retry while health is false but network is online
    if (!mounted) return;
    if (!_healthOk && _network.isConnected) {
      _lastHealthAttempt = DateTime.now();
      Future.delayed(_healthRetryInterval, () {
        if (!mounted) return;
        final last = _lastHealthAttempt;
        if (last != null &&
            DateTime.now().difference(last) >= _healthRetryInterval) {
          _prepareConnectivity();
        }
      });
    }
  }

  Widget _buildBanner(String message, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            color == AppColors.error ? Icons.warning_amber : Icons.info,
            color: color,
            size: 5.w,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 3.5.w,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
