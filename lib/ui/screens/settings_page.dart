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

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  // API Key 控制器
  final _apiKeyController = TextEditingController();
  
  // 语言配置
  String _language = AppConfig.defaultLanguage;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _shizukuConnected = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkShizukuStatus();
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
  
  Future<void> _checkShizukuStatus() async {
    final controller = DeviceController();
    final authorized = await controller.isShizukuAuthorized();
    if (mounted) {
      setState(() => _shizukuConnected = authorized);
    }
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
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
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
          
          // Shizuku 状态部分（可选）
          _buildSectionHeader(
            icon: Icons.security,
            title: 'Shizuku 状态（可选）',
          ),
          _buildCard([
            _buildStatusTile(
              title: 'Shizuku 服务',
              subtitle: _shizukuConnected ? '已连接 - 提供增强功能' : '未连接（可使用无障碍服务代替）',
              isConnected: _shizukuConnected,
              onTap: () async {
                await Navigator.pushNamed(context, '/shizuku');
                _checkShizukuStatus();
              },
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
              onTap: () {
                // TODO: 打开项目主页
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

  Widget _buildStatusTile({
    required String title,
    required String subtitle,
    required bool isConnected,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.success : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? '已连接' : '未连接',
            style: TextStyle(
              color: isConnected ? AppTheme.success : Colors.grey,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
