import 'package:flutter/material.dart';
import '../../data/repositories/model_config_repository.dart';
import '../../data/models/model_provider.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// AutoGLM 配置页面 - 独立于主模型
class AutoGLMConfigPage extends StatefulWidget {
  const AutoGLMConfigPage({super.key});

  @override
  State<AutoGLMConfigPage> createState() => _AutoGLMConfigPageState();
}

class _AutoGLMConfigPageState extends State<AutoGLMConfigPage> {
  final ModelConfigRepository _repo = ModelConfigRepository.instance;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelNameController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _modelNameController = TextEditingController();
    _loadConfig();
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadConfig() async {
    await _repo.init();
    final config = _repo.autoglmConfig;
    _apiKeyController.text = config.apiKey;
    _baseUrlController.text = config.baseUrl;
    _modelNameController.text = config.modelName;
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.grey800),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AutoGLM 配置',
          style: TextStyle(
            color: AppTheme.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final isConfigured = _repo.autoglmConfig.isConfigured;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 说明卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AutoGLM 专用配置',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'AutoGLM 用于自动化操作手机，与主对话模型独立配置。当您使用 Agent 模式时，将使用此配置。',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 状态指示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isConfigured ? AppTheme.success.withOpacity(0.1) : AppTheme.grey50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 18,
                color: isConfigured ? AppTheme.success : AppTheme.warning,
              ),
              const SizedBox(width: 8),
              Text(
                isConfigured ? '已配置，可以使用 Agent 模式' : '未配置，Agent 模式不可用',
                style: TextStyle(
                  fontSize: 13,
                  color: isConfigured ? AppTheme.success : AppTheme.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // API Key
        _buildSectionTitle('API Key'),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '输入智谱 API Key',
            filled: true,
            fillColor: AppTheme.grey50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _openApiKeyPage,
          child: Text(
            '前往智谱开放平台获取 →',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.accent,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Base URL
        _buildSectionTitle('Base URL'),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrlController,
          decoration: InputDecoration(
            hintText: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
            filled: true,
            fillColor: AppTheme.grey50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Model Name
        _buildSectionTitle('模型名称'),
        const SizedBox(height: 8),
        TextField(
          controller: _modelNameController,
          decoration: InputDecoration(
            hintText: 'autoglm-phone',
            filled: true,
            fillColor: AppTheme.grey50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 保存按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.white,
                    ),
                  )
                : const Text('保存配置', style: TextStyle(fontSize: 16)),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 重置按钮
        Center(
          child: TextButton(
            onPressed: _resetToDefault,
            child: Text(
              '恢复默认配置',
              style: TextStyle(color: AppTheme.grey500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.grey600,
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    
    final config = AutoGLMConfig(
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text.isEmpty 
          ? 'https://open.bigmodel.cn/api/paas/v4'
          : _baseUrlController.text,
      modelName: _modelNameController.text.isEmpty 
          ? 'autoglm-phone'
          : _modelNameController.text,
    );
    
    await _repo.updateAutoGLMConfig(config);
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _resetToDefault() {
    _baseUrlController.text = 'https://open.bigmodel.cn/api/paas/v4';
    _modelNameController.text = 'autoglm-phone';
    setState(() {});
  }

  Future<void> _openApiKeyPage() async {
    const url = 'https://open.bigmodel.cn/usercenter/apikeys';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开链接')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $e')),
        );
      }
    }
  }
}
