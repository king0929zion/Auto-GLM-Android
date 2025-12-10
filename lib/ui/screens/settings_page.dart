import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  // 模型配置控制�?
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  
  // Agent配置
  int _maxSteps = AppConfig.maxSteps;
  String _language = AppConfig.defaultLanguage;
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _baseUrlController.text = prefs.getString(AppConfig.keyBaseUrl) ?? 
          AppConfig.defaultBaseUrl;
      _apiKeyController.text = prefs.getString(AppConfig.keyApiKey) ?? 
          AppConfig.defaultApiKey;
      _modelNameController.text = prefs.getString(AppConfig.keyModelName) ?? 
          AppConfig.defaultModelName;
      _maxSteps = prefs.getInt(AppConfig.keyMaxSteps) ?? AppConfig.maxSteps;
      _language = prefs.getString(AppConfig.keyLanguage) ?? 
          AppConfig.defaultLanguage;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(AppConfig.keyBaseUrl, _baseUrlController.text);
      await prefs.setString(AppConfig.keyApiKey, _apiKeyController.text);
      await prefs.setString(AppConfig.keyModelName, _modelNameController.text);
      await prefs.setInt(AppConfig.keyMaxSteps, _maxSteps);
      await prefs.setString(AppConfig.keyLanguage, _language);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保�?),
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
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
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
          // 模型配置部分
          _buildSectionHeader(
            icon: Icons.memory,
            title: '模型配置',
          ),
          _buildCard([
            _buildTextField(
              controller: _baseUrlController,
              label: 'API 基础URL',
              hint: 'http://localhost:8000/v1',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入API URL';
                }
                if (!value.startsWith('http')) {
                  return '请输入有效的URL';
                }
                return null;
              },
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _apiKeyController,
              label: 'API 密钥',
              hint: 'EMPTY',
              obscure: true,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _modelNameController,
              label: '模型名称',
              hint: 'autoglm-phone-9b',
            ),
          ]),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // Agent 配置部分
          _buildSectionHeader(
            icon: Icons.tune,
            title: 'Agent 配置',
          ),
          _buildCard([
            _buildSliderTile(
              title: '最大步骤数',
              subtitle: '单次任务最多执�?$_maxSteps �?,
              value: _maxSteps.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              onChanged: (value) {
                setState(() => _maxSteps = value.round());
              },
            ),
            const Divider(height: 1),
            _buildDropdownTile(
              title: '语言',
              subtitle: '系统提示词语言',
              value: _language,
              items: const {
                'cn': '中文',
                'en': 'English',
              },
              onChanged: (value) {
                if (value != null) {
                  setState(() => _language = value);
                }
              },
            ),
          ]),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // Shizuku 状态部�?
          _buildSectionHeader(
            icon: Icons.security,
            title: 'Shizuku 状�?,
          ),
          _buildCard([
            _buildStatusTile(
              title: 'Shizuku 服务',
              subtitle: '需要安装并授权 Shizuku',
              isConnected: false, // TODO: 实际检�?
              onTap: () => Navigator.pushNamed(context, '/shizuku'),
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
              title: const Text('支持的应�?),
              subtitle: const Text('查看可用的应用列�?),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/apps'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history, color: AppTheme.accentOrange),
              title: const Text('任务历史'),
              subtitle: const Text('查看和复用历史任�?),
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

  void _resetOnboarding() async {
    // 重置首次运行状�?
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_run', true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下次启动将显示引导页�?)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.accentOrange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: items.entries.map((e) {
          return DropdownMenuItem<T>(
            value: e.key,
            child: Text(e.value),
          );
        }).toList(),
        onChanged: onChanged,
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
              color: isConnected ? AppTheme.success : AppTheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? '已连�? : '未连�?,
            style: TextStyle(
              color: isConnected ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _checkShizukuStatus() {
    // TODO: 实际检�?Shizuku 状�?
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请确保已安装并授�?Shizuku')),
    );
  }
}
