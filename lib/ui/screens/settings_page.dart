import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_strings.dart';

/// 设置页面 - 极简风格
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
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
  
  bool get _allPermissionsGranted => _accessibilityEnabled && _autoZiImeEnabled;

  final DeviceController _deviceController = DeviceController();
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkAllPermissions();
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
      _language = prefs.getString(AppConfig.keyLanguage) ?? AppConfig.defaultLanguage;
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
      _batteryOptimizationIgnored = await _deviceController.isIgnoringBatteryOptimizations();
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getStr(String key) => AppStrings.getString(key, _language);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.black))
            : CustomScrollView(
                slivers: [
                  // 极简 AppBar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: AppTheme.grey50,
                    surfaceTintColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      _getStr('settings'),
                      style: const TextStyle(
                        fontSize: AppTheme.fontSize18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: AppTheme.space16),
                        child: TextButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.black,
                            foregroundColor: AppTheme.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.white,
                                  ),
                                )
                              : Text(
                                  _getStr('save'),
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontSize13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  
                  // 内容
                  SliverPadding(
                    padding: const EdgeInsets.all(AppTheme.space20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 模型配置
                              _SectionHeader(title: _getStr('intelligence')),
                              _SettingsCard(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.psychology_rounded,
                                    title: '模型配置',
                                    subtitle: '配置对话模型供应商',
                                    onTap: () => Navigator.pushNamed(context, '/provider-config'),
                                  ),
                                  _SettingsTile(
                                    icon: Icons.auto_awesome_rounded,
                                    title: 'AutoGLM 配置',
                                    subtitle: '配置自动化 Agent',
                                    onTap: () => Navigator.pushNamed(context, '/autoglm-config'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppTheme.space24),

                              // 权限配置
                              _SectionHeader(title: _getStr('permissions')),
                              _SettingsCard(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.security_rounded,
                                    title: '权限配置',
                                    subtitle: _allPermissionsGranted
                                        ? '所有权限已授予'
                                        : '需要配置权限',
                                    trailing: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _allPermissionsGranted 
                                            ? AppTheme.success 
                                            : AppTheme.warning,
                                      ),
                                    ),
                                    onTap: () => Navigator.pushNamed(context, '/permissions'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppTheme.space24),

                              // 通用设置
                              _SectionHeader(title: _getStr('general')),
                              _SettingsCard(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.language_rounded,
                                    title: _getStr('language'),
                                    subtitle: _language == 'cn' ? '简体中文' : 'English',
                                    onTap: _showLanguageSelector,
                                  ),
                                  _SettingsTile(
                                    icon: Icons.history_rounded,
                                    title: _getStr('history'),
                                    onTap: () => Navigator.pushNamed(context, '/history'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppTheme.space24),

                              // 关于
                              _SectionHeader(title: _getStr('about')),
                              _SettingsCard(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.code_rounded,
                                    title: _getStr('github'),
                                    onTap: () => _launchGithub(''),
                                  ),
                                  _SettingsTile(
                                    icon: Icons.info_rounded,
                                    title: _getStr('version'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.space8,
                                        vertical: AppTheme.space4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.grey100,
                                        borderRadius: BorderRadius.circular(AppTheme.radius4),
                                      ),
                                      child: Text(
                                        AppConfig.appVersion,
                                        style: const TextStyle(
                                          fontSize: AppTheme.fontSize12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.grey600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppTheme.space48),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showLanguageSelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.space24),
              Text(
                _getStr('selectLanguage'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSize16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              _LanguageOption(
                flag: '🇺🇸',
                label: 'English',
                isSelected: _language == 'en',
                onTap: () => Navigator.pop(context, 'en'),
              ),
              _LanguageOption(
                flag: '🇨🇳',
                label: '简体中文',
                isSelected: _language == 'cn',
                onTap: () => Navigator.pop(context, 'cn'),
              ),
              const SizedBox(height: AppTheme.space16),
            ],
          ),
        ),
      ),
    );

    if (result != null && result != _language) {
      setState(() => _language = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyLanguage, _language);
    }
  }

  Future<void> _launchGithub(String path) async {
    final uri = Uri.parse('https://github.com/king0929zion/Auto-GLM-Android$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

// ============================================
// 组件
// ============================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.space4,
        bottom: AppTheme.space8,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: AppTheme.fontSize11,
          fontWeight: FontWeight.w600,
          color: AppTheme.grey500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.grey150),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                const Divider(height: 1, indent: 52),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final bool isRequired;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.isRequired,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isGranted ? AppTheme.black : AppTheme.grey100,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isGranted ? AppTheme.white : AppTheme.grey600,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSize14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRequired && !isGranted) ...[
                        const SizedBox(width: AppTheme.space6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(AppTheme.radius4),
                          ),
                          child: const Text(
                            '!',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize12,
                      color: isGranted ? AppTheme.success : AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space12,
                  vertical: AppTheme.space6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey300),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey700,
                  ),
                ),
              )
            else
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.black,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.grey700),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSize14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSize12,
                        color: AppTheme.grey500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.grey300,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space24,
          vertical: AppTheme.space14,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppTheme.space12),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSize15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.black,
              ),
          ],
        ),
      ),
    );
  }
}
