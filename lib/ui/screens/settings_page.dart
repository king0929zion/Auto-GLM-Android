import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // API Key 控制器
  final _apiKeyController = TextEditingController();

  // 语言配置
  String _language = AppConfig.defaultLanguage;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;

  // 权限状态
  bool _accessibilityEnabled = false;
  bool _overlayPermission = false;
  bool _shizukuInstalled = false;
  bool _shizukuRunning = false;
  bool _shizukuAuthorized = false;
  bool _batteryOptimizationIgnored = false;
  bool _autoZiImeEnabled = false;

  final DeviceController _deviceController = DeviceController();
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkAllPermissions();
    // 启动定时检查
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _checkAllPermissions();
    });
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _apiKeyController.text =
          prefs.getString(AppConfig.keyApiKey) ?? AppConfig.defaultApiKey;
      _language =
          prefs.getString(AppConfig.keyLanguage) ?? AppConfig.defaultLanguage;
      _isLoading = false;
    });
  }

  Future<void> _checkAllPermissions() async {
    try {
      _accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
      _overlayPermission = await _deviceController.checkOverlayPermission();
      _shizukuInstalled = await _deviceController.isShizukuInstalled();
      _shizukuRunning = await _deviceController.isShizukuRunning();
      _shizukuAuthorized = await _deviceController.isShizukuAuthorized();
      _batteryOptimizationIgnored =
          await _deviceController.isIgnoringBatteryOptimizations();
      _autoZiImeEnabled = await _deviceController.isAutoZiImeEnabled();
    } catch (e) {
      debugPrint('Check permissions error: $e');
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(AppConfig.keyApiKey, _apiKeyController.text);
      await prefs.setString(AppConfig.keyLanguage, _language);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Default background color (AppTheme.scaffoldBackgroundColor)
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: AppTheme.scaffoldWhite,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            foregroundColor: AppTheme.primaryBlack,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlack,
                disabledForegroundColor: AppTheme.grey400,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: AppTheme.primaryBlack,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(60, 32),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: Colors.white
                      ),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlack))
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // 权限状态部分
          _buildSectionHeader(title: 'PERMISSIONS'),
          _buildCard([
            _buildPermissionTile(
              title: 'Accessibility Service',
              subtitle: _accessibilityEnabled ? 'Active' : 'Required',
              icon: Icons.accessibility_new_outlined,
              isGranted: _accessibilityEnabled,
              isRequired: true,
              onTap: () => _deviceController.openAccessibilitySettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: 'AutoZi Input Method',
              subtitle: _autoZiImeEnabled ? 'Active' : 'Required for reliable input',
              icon: Icons.keyboard_outlined,
              isGranted: _autoZiImeEnabled,
              isRequired: true,
              onTap: () => _deviceController.openInputMethodSettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: 'Shizuku',
              subtitle: _getShizukuStatusText(),
              icon: Icons.adb_outlined,
              isGranted: _shizukuAuthorized,
              isRequired: true,
              onTap: _handleShizukuAction,
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: 'Floating Window',
              subtitle: _overlayPermission ? 'Authorized' : 'Optional',
              icon: Icons.picture_in_picture_alt_outlined,
              isGranted: _overlayPermission,
              isRequired: false,
              onTap: () => _deviceController.openOverlaySettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: 'Battery Optimization',
              subtitle: _batteryOptimizationIgnored ? 'Ignored' : 'Recommended',
              icon: Icons.battery_charging_full_outlined,
              isGranted: _batteryOptimizationIgnored,
              isRequired: false,
              onTap: () => _deviceController.requestIgnoreBatteryOptimizations(),
            ),
          ]),

          const SizedBox(height: 32),

          // API Key 配置部分
          _buildSectionHeader(title: 'MODEL CONFIG'),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zhipu AI API Key',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    cursorColor: AppTheme.primaryBlack,
                    style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'API Key is required';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter your API Key',
                      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.grey50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryBlack, width: 1),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.grey600,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 获取 API Key 链接
                  GestureDetector(
                    onTap: _openApiKeyPage,
                    child: Row(
                      children: const [
                        Text(
                          'Get API Key',
                          style: TextStyle(
                            color: AppTheme.primaryBlack,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_outward, size: 14, color: AppTheme.primaryBlack),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  const Text(
                    'Powered by Zhipu AI (GLM-4V)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 32),

          // 功能入口
          _buildSectionHeader(title: 'GENERAL'),
          _buildCard([
             _buildListTile(
              icon: Icons.apps_outlined,
              title: 'Supported Apps',
              subtitle: 'View compatible applications',
              onTap: () => Navigator.pushNamed(context, '/apps'),
            ),
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: Icons.history_outlined,
              title: 'Task History',
              subtitle: 'Review past activities',
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
          ]),

          const SizedBox(height: 32),

          // 关于
          _buildSectionHeader(title: 'ABOUT'),
          _buildCard([
            _buildListTile(
              icon: Icons.info_outline,
              title: 'Version',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppConfig.appVersion,
                  style: const TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary
                  ),
                ),
              ),
              onTap: null, // No action
            ),
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: Icons.code_outlined,
              title: 'Source Code',
              subtitle: 'Open-AutoGLM on GitHub',
              onTap: () async {
                final uri = Uri.parse('https://github.com/AJinNight/Auto-GLM-Android');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
             const Divider(height: 1, indent: 56),
             _buildListTile(
               icon: Icons.refresh_outlined,
               title: 'Reset Onboarding',
               onTap: _resetOnboarding,
             ),
          ]),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isGranted ? AppTheme.primaryBlack : AppTheme.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isGranted ? Colors.white : AppTheme.grey600,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlack,
                        ),
                      ),
                      if (isRequired && !isGranted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlack,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REQ',
                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isGranted ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryBlack, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(
                    color: AppTheme.primaryBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(Icons.check_circle, color: AppTheme.primaryBlack, size: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryBlack),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) 
              trailing
            else if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.grey300),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary, 
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
