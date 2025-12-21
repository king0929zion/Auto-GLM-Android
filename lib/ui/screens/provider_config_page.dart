import 'package:flutter/material.dart';
import '../../data/repositories/model_config_repository.dart';
import '../../data/models/model_provider.dart';
import '../theme/app_theme.dart';
import 'provider_detail_page.dart';

/// 供应商配置页面
class ProviderConfigPage extends StatefulWidget {
  const ProviderConfigPage({super.key});

  @override
  State<ProviderConfigPage> createState() => _ProviderConfigPageState();
}

class _ProviderConfigPageState extends State<ProviderConfigPage> {
  final ModelConfigRepository _repo = ModelConfigRepository.instance;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await _repo.init();
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
          '模型配置',
          style: TextStyle(
            color: AppTheme.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.grey700),
            onPressed: _showAddCustomProvider,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _buildProviderList(),
    );
  }

  Widget _buildProviderList() {
    final providers = _repo.providers;
    final selectedCount = _repo.selectedModelIds.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已选模型数量提示
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  '已选择 $selectedCount/${ModelConfigRepository.maxSelectedModels} 个模型',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 供应商列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              return _buildProviderCard(provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard(ModelProvider provider) {
    final hasApiKey = provider.apiKey.isNotEmpty;
    final modelCount = provider.models.length;
    final selectedInProvider = provider.models.where(
      (m) => _repo.selectedModelIds.contains(m.id)
    ).length;
    
    return GestureDetector(
      onTap: () => _openProviderDetail(provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.grey50,
          borderRadius: BorderRadius.circular(12),
          border: hasApiKey 
              ? Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasApiKey ? AppTheme.accent.withOpacity(0.1) : AppTheme.grey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getProviderIcon(provider.id),
                color: hasApiKey ? AppTheme.accent : AppTheme.grey400,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey800,
                        ),
                      ),
                      if (!provider.isBuiltIn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.grey200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '自定义',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasApiKey 
                        ? '$modelCount 个模型${selectedInProvider > 0 ? '，已选 $selectedInProvider 个' : ''}'
                        : '点击配置 API Key',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasApiKey ? AppTheme.grey500 : AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.grey400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(String providerId) {
    switch (providerId) {
      case 'openai':
        return Icons.auto_awesome;
      case 'deepseek':
        return Icons.water_drop;
      case 'siliconflow':
        return Icons.memory;
      case 'zhipu':
        return Icons.psychology;
      case 'nvidia':
        return Icons.developer_board;
      case 'modelscope':
        return Icons.hub;
      case 'openrouter':
        return Icons.router;
      default:
        return Icons.cloud;
    }
  }

  void _openProviderDetail(ModelProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderDetailPage(providerId: provider.id),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showAddCustomProvider() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('添加自定义供应商'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如: My Provider',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.example.com/v1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppTheme.grey600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                _repo.addCustomProvider(nameController.text, urlController.text);
                Navigator.pop(context);
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
