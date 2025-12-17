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

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
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
  bool _adbKeyboardInstalled = false;
  
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
      _apiKeyController.text = prefs.getString(AppConfig.keyApiKey) ?? 
          AppConfig.defaultApiKey;
      _language = prefs.getString(AppConfig.keyLanguage) ?? 
          AppConfig.defaultLanguage;
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
      _adbKeyboardInstalled = await _deviceController.isAdbKeyboardInstalled();
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
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
            _buildPermissionTile(
              title: 'Shizuku',
              subtitle: _getShizukuStatusText(),
              icon: Icons.developer_mode,
              isGranted: _shizukuAuthorized,
              isRequired: false,
              onTap: _handleShizukuAction,
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
              onTap: () => _deviceController.requestIgnoreBatteryOptimizations(),
            ),
            const Divider(height: 1),
            // ADB Keyboard
            _buildPermissionTile(
              title: 'ADB Keyboard',
              subtitle: _adbKeyboardInstalled 
                  ? '已安装 - 配合Shizuku提供更可靠的输入' 
                  : '未安装（可选，需Shizuku）',
              icon: Icons.keyboard,
              isGranted: _adbKeyboardInstalled,
              isRequired: false,
              onTap: () => _showAdbKeyboardGuide(),
            ),
          ]),
          
          // 输入方式说明卡片
          const SizedBox(height: AppTheme.spacingMD),
          _buildInputMethodInfoCard(),
          
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
                          _obscureApiKey ? Icons.visibility_off : Icons.visibility,
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
                          Icon(Icons.open_in_new, size: 16, color: AppTheme.accentOrange),
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
                final uri = Uri.parse('https://github.com/AJinNight/Auto-GLM-Android');
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
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isGranted 
              ? AppTheme.success.withOpacity(0.1)
              : (isRequired ? AppTheme.error.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isGranted 
              ? AppTheme.success
              : (isRequired ? AppTheme.error : Colors.grey),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(title),
          if (isRequired && !isGranted) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isGranted ? AppTheme.success : AppTheme.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isGranted ? AppTheme.success : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
            color: isGranted ? AppTheme.success : Colors.grey,
            size: isGranted ? 20 : 14,
          ),
        ],
      ),
      onTap: isGranted ? null : onTap,
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
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  /// 显示 ADB Keyboard 安装引导
  void _showAdbKeyboardGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.keyboard, color: AppTheme.accentOrange),
            const SizedBox(width: 12),
            const Text('ADB Keyboard'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ADB Keyboard 配合 Shizuku 可以提供更可靠的中文输入能力，特别是在微信等应用中。',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '安装步骤：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 下载 ADB Keyboard APK\n'
              '2. 安装并在设置中启用\n'
              '3. 确保 Shizuku 已授权',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = Uri.parse('https://github.com/nicokosi/adb-keyboard/releases');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }
  
  /// 构建输入方式说明卡片
  Widget _buildInputMethodInfoCard() {
    final bool useShizukuInput = _shizukuAuthorized;
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: useShizukuInput 
            ? AppTheme.success.withOpacity(0.1)
            : AppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: useShizukuInput 
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.info.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            useShizukuInput ? Icons.keyboard : Icons.accessibility_new,
            color: useShizukuInput ? AppTheme.success : AppTheme.info,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前输入方式',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  useShizukuInput 
                      ? 'Shizuku + ADB Keyboard（推荐）'
                      : '无障碍服务',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (!useShizukuInput) ...[
                  const SizedBox(height: 4),
                  Text(
                    '授权Shizuku可获得更可靠的输入（需安装ADB Keyboard）',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
