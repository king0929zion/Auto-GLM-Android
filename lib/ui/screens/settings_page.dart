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
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('设置',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlack,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryBlack),
                    )
                  : const Text('保存',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // 权限状态部分（新增）
          _buildSectionHeader(
            icon: Icons.security,
            title: '权限状态',
          ),
          _buildCard([
            // 无障碍服务
            _buildPermissionTile(
              title: '无障碍服务',
              subtitle: _accessibilityEnabled ? '已启用' : '未启用（必需）',
              icon: Icons.accessibility_new,
              isGranted: _accessibilityEnabled,
              isRequired: true,
              onTap: () => _deviceController.openAccessibilitySettings(),
            ),
            const Divider(height: 1),
            // AutoZi 输入法
            _buildPermissionTile(
              title: 'AutoZi 输入法',
              subtitle: _autoZiImeEnabled ? '已启用 - 支持可靠的中文输入' : '未启用（必需）',
              icon: Icons.keyboard,
              isGranted: _autoZiImeEnabled,
              isRequired: true,
              onTap: () => _deviceController.openInputMethodSettings(),
            ),
            const Divider(height: 1),
            // Shizuku
            _buildPermissionTile(
              title: 'Shizuku',
              subtitle: _getShizukuStatusText(),
              icon: Icons.developer_mode,
              isGranted: _shizukuAuthorized,
              isRequired: true,
              onTap: _handleShizukuAction,
            ),
            const Divider(height: 1),
            // 悬浮窗权限
            _buildPermissionTile(
              title: '悬浮窗权限',
              subtitle: _overlayPermission ? '已授权' : '未授权（可选）',
              icon: Icons.picture_in_picture,
              isGranted: _overlayPermission,
              isRequired: false,
              onTap: () => _deviceController.openOverlaySettings(),
            ),
            const Divider(height: 1),
            // 电池优化白名单
            _buildPermissionTile(
              title: '电池优化白名单',
              subtitle: _batteryOptimizationIgnored
                  ? '已加入 - 防止无障碍服务被关闭'
                  : '未加入（强烈推荐）',
              icon: Icons.battery_saver,
              isGranted: _batteryOptimizationIgnored,
              isRequired: false,
              onTap: () =>
                  _deviceController.requestIgnoreBatteryOptimizations(),
            ),
          ]),

          const SizedBox(height: AppTheme.spacingLG),

          // API Key 配置部分
          _buildSectionHeader(
            icon: Icons.key,
            title: '智谱 API 配置',
          ),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 API Key';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: '请输入您的智谱 API Key',
                      prefixIcon: const Icon(Icons.vpn_key),
                      filled: true,
                      fillColor: Colors.transparent,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),

                  // 获取 API Key 按钮
                  InkWell(
                    onTap: _openApiKeyPage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMD,
                        vertical: AppTheme.spacingSM,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: AppTheme.accentOrange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 16, color: AppTheme.accentOrange),
                          const SizedBox(width: 8),
                          Text(
                            '获取 API Key',
                            style: TextStyle(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingSM),

                  Text(
                    '提示：使用智谱开放平台的 autoglm-phone 模型',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: AppTheme.spacingLG),

          // 功能入口
          _buildSectionHeader(
            icon: Icons.apps,
            title: '功能',
          ),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.apps, color: AppTheme.accentOrange),
              title: const Text('支持的应用'),
              subtitle: const Text('查看可用的应用列表'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/apps'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history, color: AppTheme.accentOrange),
              title: const Text('任务历史'),
              subtitle: const Text('查看和复用历史任务'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
          ]),

          const SizedBox(height: AppTheme.spacingLG),

          // 关于部分
          _buildSectionHeader(
            icon: Icons.info_outline,
            title: '关于',
          ),
          _buildCard([
            ListTile(
              title: const Text('版本'),
              trailing: Text(
                AppConfig.appVersion,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('项目主页'),
              subtitle: const Text('Open-AutoGLM'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri =
                    Uri.parse('https://github.com/AJinNight/Auto-GLM-Android');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('重置引导'),
              subtitle: const Text('重新显示欢迎页面'),
              onTap: _resetOnboarding,
            ),
          ]),

          const SizedBox(height: AppTheme.spacingXL),
        ],
      ),
    );
  }

  String _getShizukuStatusText() {
    if (!_shizukuInstalled) return '未安装（可选）';
    if (!_shizukuRunning) return '服务未启动';
    if (!_shizukuAuthorized) return '等待授权';
    return '已授权';
  }

  Future<void> _handleShizukuAction() async {
    if (!_shizukuInstalled) {
      // 打开 Shizuku 下载页面
      final uri = Uri.parse('https://shizuku.rikka.app/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!_shizukuRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先打开 Shizuku 应用并启动服务')),
      );
      return;
    }

    // 请求授权
    await _deviceController.requestShizukuPermission();
    await Future.delayed(const Duration(seconds: 1));
    _checkAllPermissions();
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isGranted
                  ? AppTheme.primaryBlack
                  : (isRequired ? AppTheme.error : AppTheme.grey400),
              size: 24,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRequired && !isGranted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '必需',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isGranted ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlack,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '开启',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Icon(Icons.check, color: AppTheme.success, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openApiKeyPage() async {
    final uri = Uri.parse('https://bigmodel.cn/usercenter/proj-mgmt/apikeys');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _resetOnboarding() async {
    // 重置首次运行状态
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_run', true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下次启动将显示引导页面')),
      );
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingXS,
        bottom: AppTheme.spacingSM,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentOrange),
          const SizedBox(width: AppTheme.spacingSM),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.warmBeige),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
