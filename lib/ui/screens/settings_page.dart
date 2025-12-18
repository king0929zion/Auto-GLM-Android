import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';
import 'model_settings_page.dart';
import '../../l10n/app_strings.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // 语言配置
  String _language = AppConfig.defaultLanguage;

  bool _isLoading = true;
  bool _isSaving = false;

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

      await prefs.setString(AppConfig.keyLanguage, _language);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
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

  String _getStr(String key) => AppStrings.getString(key, _language);

  Future<void> _showLanguageSelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _getStr('selectLanguage'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlack),
              ),
            ),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: _language == 'en' ? const Icon(Icons.check_circle, color: AppTheme.primaryBlack) : null,
              onTap: () => Navigator.pop(context, 'en'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Text('🇨🇳', style: TextStyle(fontSize: 24)),
              title: const Text('简体中文'),
              trailing: _language == 'cn' ? const Icon(Icons.check_circle, color: AppTheme.primaryBlack) : null,
              onTap: () => Navigator.pop(context, 'cn'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (result != null && result != _language) {
      setState(() => _language = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyLanguage, _language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text(_getStr('settings'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: AppTheme.grey50,
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
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_getStr('save'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlack))
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Permissions
          _buildSectionHeader(title: _getStr('permissions')),
          _buildCard([
            _buildPermissionTile(
              title: _getStr('accessibility'),
              subtitle: _accessibilityEnabled ? _getStr('active') : _getStr('required'),
              icon: Icons.accessibility_new_outlined,
              isGranted: _accessibilityEnabled,
              isRequired: true,
              onTap: () => _deviceController.openAccessibilitySettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: _getStr('inputMethod'),
              subtitle: _autoZiImeEnabled ? _getStr('active') : _getStr('required'),
              icon: Icons.keyboard_outlined,
              isGranted: _autoZiImeEnabled,
              isRequired: true,
              onTap: () => _deviceController.openInputMethodSettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: _getStr('shizuku'),
              subtitle: _getShizukuStatusText(),
              icon: Icons.adb_outlined,
              isGranted: _shizukuAuthorized,
              isRequired: true,
              onTap: _handleShizukuAction,
            ),
          ]),
          
          const SizedBox(height: 24),

          // Enhancements
          _buildSectionHeader(title: _getStr('enhancements')),
          _buildCard([
            _buildPermissionTile(
              title: _getStr('floatingWindow'),
              subtitle: _overlayPermission ? _getStr('active') : _getStr('optional'),
              icon: Icons.picture_in_picture_alt_outlined,
              isGranted: _overlayPermission,
              isRequired: false,
              onTap: () => _deviceController.openOverlaySettings(),
            ),
            const Divider(height: 1, indent: 56),
            _buildPermissionTile(
              title: _getStr('batteryOpt'),
              subtitle: _batteryOptimizationIgnored ? _getStr('ignored') : _getStr('recommended'),
              icon: Icons.battery_charging_full_outlined,
              isGranted: _batteryOptimizationIgnored,
              isRequired: false,
              onTap: () => _deviceController.requestIgnoreBatteryOptimizations(),
            ),
          ]),

          const SizedBox(height: 32),

          // Intelligence
          _buildSectionHeader(title: _getStr('intelligence')),
          _buildCard([
             _buildListTile(
              icon: Icons.psychology_outlined,
              title: _getStr('modelConfig'),
              subtitle: 'AutoGLM / Doubao',
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const ModelSettingsPage()),
              ),
            ),
          ]),

          const SizedBox(height: 32),

          // General
          _buildSectionHeader(title: _getStr('general')),
          _buildCard([
             _buildListTile(
              icon: Icons.language,
              title: _getStr('language'),
              subtitle: _language == 'cn' ? '简体中文' : 'English',
              onTap: _showLanguageSelector,
            ),
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: Icons.history_outlined,
              title: _getStr('history'),
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            const Divider(height: 1, indent: 56),
             _buildListTile(
              icon: Icons.apps_outlined,
              title: _getStr('supportedApps'),
              onTap: () => Navigator.pushNamed(context, '/apps'),
            ),
          ]),

          const SizedBox(height: 32),

          // About
          _buildSectionHeader(title: _getStr('about')),
          _buildCard([
            _buildListTile(
              icon: Icons.description_outlined,
              title: _getStr('documentation'),
              onTap: () => _launchGithub(''),
            ),
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: Icons.code_outlined,
              title: _getStr('github'),
              onTap: () => _launchGithub(''),
            ),
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: Icons.info_outline,
              title: _getStr('version'),
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
              onTap: null, 
            ),
             const Divider(height: 1, indent: 56),
             _buildListTile(
               icon: Icons.refresh_outlined,
               title: _getStr('resetOnboarding'),
               onTap: _resetOnboarding,
             ),
          ]),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _launchGithub(String path) async {
    final uri = Uri.parse('https://github.com/king0929zion/Auto-GLM-Android$path');
     if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
     }
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
  String _getShizukuStatusText() {
    if (!_shizukuInstalled) return 'Not Installed';
    if (!_shizukuRunning) return 'Service Not Running';
    if (!_shizukuAuthorized) return 'Awaiting Authorization';
    return 'Authorized';
  }

  Future<void> _handleShizukuAction() async {
    if (!_shizukuInstalled) {
      final uri = Uri.parse('https://shizuku.rikka.app/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!_shizukuRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please start Shizuku service first.')),
      );
      return;
    }

    await _deviceController.requestShizukuPermission();
    await Future.delayed(const Duration(seconds: 1));
    _checkAllPermissions();
  }

  void _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_run', true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding will be shown on next launch.')),
      );
    }
  }
}
