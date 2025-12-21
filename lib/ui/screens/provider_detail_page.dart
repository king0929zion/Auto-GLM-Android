import 'package:flutter/material.dart';
import '../../data/repositories/model_config_repository.dart';
import '../../data/models/model_provider.dart';
import '../theme/app_theme.dart';

/// 供应商详情页面 - 配置 API Key 和选择模型
class ProviderDetailPage extends StatefulWidget {
  final String providerId;
  
  const ProviderDetailPage({super.key, required this.providerId});

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  final ModelConfigRepository _repo = ModelConfigRepository.instance;
  late TextEditingController _apiKeyController;
  
  ModelProvider? _provider;
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadProvider();
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
  
  void _loadProvider() {
    _provider = _repo.providers.firstWhere((p) => p.id == widget.providerId);
    _apiKeyController.text = _provider?.apiKey ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Scaffold(
        body: Center(child: Text('供应商不存在')),
      );
    }
    
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.grey800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _provider!.name,
          style: const TextStyle(
            color: AppTheme.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (!_provider!.isBuiltIn)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _deleteProvider,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Key 配置
          _buildSectionTitle('API Key'),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '输入 API Key',
              filled: true,
              fillColor: AppTheme.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.save, color: AppTheme.accent),
                onPressed: _saveApiKey,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 获取模型按钮
          _buildSectionTitle('可用模型'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFetching ? null : _fetchModels,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isFetching 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: Text(_isFetching ? '获取中...' : '获取模型列表'),
            ),
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 模型列表
          if (_provider!.models.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 40, color: AppTheme.grey300),
                  const SizedBox(height: 8),
                  Text(
                    '暂无模型',
                    style: TextStyle(color: AppTheme.grey500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '请先配置 API Key 并获取模型列表',
                    style: TextStyle(color: AppTheme.grey400, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._provider!.models.map((model) => _buildModelItem(model)),
          
          const SizedBox(height: 24),
          
          // 选择限制提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.grey500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '最多可选择 ${ModelConfigRepository.maxSelectedModels} 个模型，已选 ${_repo.selectedModelIds.length} 个',
                    style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildModelItem(Model model) {
    final isSelected = _repo.selectedModelIds.contains(model.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withOpacity(0.05) : AppTheme.grey50,
        borderRadius: BorderRadius.circular(10),
        border: isSelected 
            ? Border.all(color: AppTheme.accent.withOpacity(0.3))
            : null,
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => _toggleModel(model),
        activeColor: AppTheme.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          model.displayName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.accent : AppTheme.grey800,
          ),
        ),
        subtitle: Text(
          model.modelId,
          style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
        ),
      ),
    );
  }

  Future<void> _saveApiKey() async {
    await _repo.updateProviderApiKey(widget.providerId, _apiKeyController.text);
    _loadProvider();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key 已保存'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _fetchModels() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() => _errorMessage = '请先输入 API Key');
      return;
    }
    
    // 先保存 API Key
    await _repo.updateProviderApiKey(widget.providerId, _apiKeyController.text);
    
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });
    
    try {
      await _repo.fetchModels(widget.providerId);
      _loadProvider();
      setState(() => _isFetching = false);
    } catch (e) {
      setState(() {
        _isFetching = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _toggleModel(Model model) async {
    final success = await _repo.toggleModelSelection(model.id);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已达到最大选择数量 (5个)'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
    _loadProvider();
    setState(() {});
  }

  void _deleteProvider() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除供应商'),
        content: Text('确定要删除 ${_provider!.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _repo.deleteProvider(widget.providerId);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
