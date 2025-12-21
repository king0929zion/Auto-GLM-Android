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
  final TextEditingController _searchController = TextEditingController();
  
  ModelProvider? _provider;
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
    _searchController.dispose();
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
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.grey700),
            onPressed: _showAddModelDialog,
            tooltip: '添加模型',
          ),
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

          // 搜索模型
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索模型（名称或 Model ID）',
              filled: true,
              fillColor: AppTheme.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.grey500),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.grey500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 模型列表
          if (_filteredModels().isEmpty)
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
                    _provider!.models.isEmpty ? '暂无模型' : '未找到匹配的模型',
                    style: TextStyle(color: AppTheme.grey500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _provider!.models.isEmpty ? '请先配置 API Key 并获取模型列表' : '换个关键词试试',
                    style: TextStyle(color: AppTheme.grey400, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._filteredModels().map((model) => _buildModelItem(model)),
          
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
    final isDefault = _repo.activeModelId == model.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withOpacity(0.05) : AppTheme.grey50,
        borderRadius: BorderRadius.circular(10),
        border: isSelected 
            ? Border.all(color: AppTheme.accent.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) => _toggleModel(model),
            activeColor: AppTheme.accent,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _toggleModel(model),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppTheme.accent : AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.modelId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isDefault ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: isDefault ? AppTheme.accent : AppTheme.grey600,
            ),
            onPressed: () => _setAsDefaultModel(model),
            tooltip: '设为默认',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.grey600),
            onPressed: () => _showEditModelDialog(model),
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.grey600),
            onPressed: () => _confirmDeleteModel(model),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  List<Model> _filteredModels() {
    final provider = _provider;
    if (provider == null) return const [];

    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return provider.models;

    return provider.models.where((m) {
      return m.displayName.toLowerCase().contains(keyword) ||
          m.modelId.toLowerCase().contains(keyword);
    }).toList();
  }

  void _showAddModelDialog() {
    final modelIdController = TextEditingController();
    final displayNameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('添加模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelIdController,
              decoration: const InputDecoration(
                labelText: 'Model ID',
                hintText: '例如：gpt-4o',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(
                labelText: '显示名称（可选）',
                hintText: '不填则默认使用 modelId（会自动去掉 / 前缀）',
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
            onPressed: () async {
              final modelId = modelIdController.text.trim();
              final displayName = displayNameController.text.trim();
              try {
                await _repo.addManualModel(
                  widget.providerId,
                  modelId: modelId,
                  displayName: displayName.isEmpty ? null : displayName,
                );
                if (!mounted) return;
                Navigator.of(this.context).pop();
                _loadProvider();
                if (mounted) setState(() {});
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('添加失败：$e')),
                );
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

  void _showEditModelDialog(Model model) {
    final modelIdController = TextEditingController(text: model.modelId);
    final displayNameController = TextEditingController(text: model.displayName);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('编辑模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelIdController,
              decoration: const InputDecoration(
                labelText: 'Model ID',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(
                labelText: '显示名称（可选）',
                hintText: '不填则自动从 modelId 生成',
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
            onPressed: () async {
              final modelId = modelIdController.text.trim();
              final displayName = displayNameController.text.trim();
              try {
                await _repo.updateModel(
                  widget.providerId,
                  modelUuid: model.id,
                  modelId: modelId,
                  displayName: displayName.isEmpty ? null : displayName,
                );
                if (!mounted) return;
                Navigator.of(this.context).pop();
                _loadProvider();
                if (mounted) setState(() {});
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('保存失败：$e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteModel(Model model) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除模型'),
        content: Text('确定要删除 ${model.displayName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppTheme.grey600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _repo.deleteModel(widget.providerId, model.id);
              _loadProvider();
              if (mounted) setState(() {});
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.error)),
          ),
        ],
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
    if (model.modelId.toLowerCase().contains('autoglm')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不建议将 AutoGLM 作为主对话模型，请使用 Agent 配置页单独配置 AutoGLM')),
      );
      return;
    }
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

  Future<void> _setAsDefaultModel(Model model) async {
    if (model.modelId.toLowerCase().contains('autoglm')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不建议将 AutoGLM 作为主对话模型，请在 AutoGLM 配置页单独配置')),
      );
      return;
    }

    final isSelected = _repo.selectedModelIds.contains(model.id);
    if (!isSelected) {
      final success = await _repo.toggleModelSelection(model.id);
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已达到最大选择数量 (5个)'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
    }

    await _repo.setActiveModel(model.id);
    _loadProvider();
    if (mounted) setState(() {});
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
