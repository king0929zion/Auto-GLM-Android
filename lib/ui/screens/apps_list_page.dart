import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../config/apps.dart';

/// 支持的应用列表页�?
/// 复刻原Python项目�?--list-apps 功能
class AppsListPage extends StatefulWidget {
  const AppsListPage({super.key});

  @override
  State<AppsListPage> createState() => _AppsListPageState();
}

class _AppsListPageState extends State<AppsListPage> {
  String _searchQuery = '';
  String _selectedCategory = '全部';
  
  // 应用分类
  static const Map<String, List<String>> _categories = {
    '全部': [],
    '社交通讯': ['微信', 'QQ', '微博', 'Telegram', 'WhatsApp', 'Twitter'],
    '电商购物': ['淘宝', '京东', '拼多�?, 'Temu'],
    '生活服务': ['美团', '大众点评', '饿了�?, '高德地图', '百度地图', '滴滴出行'],
    '视频娱乐': ['bilibili', '抖音', '快手', '腾讯视频', '爱奇�?, '优酷视频'],
    '音乐': ['网易云音�?, 'QQ音乐', '汽水音乐', '喜马拉雅'],
    '阅读': ['小红�?, '知乎', '豆瓣', '番茄小说', '今日头条'],
    '旅行出行': ['携程', '铁路12306', '去哪�?],
    '工具': ['Settings', 'Chrome', 'Gmail', 'Clock', 'Contacts'],
    '游戏': ['星穹铁道', '恋与深空'],
  };

  List<MapEntry<String, String>> get _filteredApps {
    var apps = AppPackages.packages.entries.toList();
    
    // 按分类筛�?
    if (_selectedCategory != '全部') {
      final categoryApps = _categories[_selectedCategory] ?? [];
      apps = apps.where((e) => categoryApps.contains(e.key)).toList();
    }
    
    // 按搜索词筛�?
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((e) => 
        e.key.toLowerCase().contains(query) ||
        e.value.toLowerCase().contains(query)
      ).toList();
    }
    
    // 按名称排序，去重
    final seen = <String>{};
    apps = apps.where((e) => seen.add(e.value)).toList();
    apps.sort((a, b) => a.key.compareTo(b.key));
    
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _filteredApps;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('支持的应�?),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${filteredApps.length} 个应�?,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索�?
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索应用名称或包�?..',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // 分类筛�?
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories.keys.elementAt(index);
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: AppTheme.accentOrange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          // 应用列表
          Expanded(
            child: filteredApps.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  itemCount: filteredApps.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    return _buildAppTile(app.key, app.value);
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.apps,
            size: 64,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          const Text(
            '没有找到匹配的应�?,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppTile(String appName, String packageName) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.secondaryBeige,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            appName.isNotEmpty ? appName[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentOrangeDeep,
            ),
          ),
        ),
      ),
      title: Text(
        appName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        packageName,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textHint,
          fontFamily: 'monospace',
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        color: AppTheme.textHint,
        onPressed: () {
          // 复制包名到剪贴板
          _copyToClipboard(packageName);
        },
        tooltip: '复制包名',
      ),
      onTap: () {
        _showAppDetails(appName, packageName);
      },
    );
  }
  
  void _copyToClipboard(String text) {
    // 复制到剪贴板
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复�? $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showAppDetails(String appName, String packageName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动�?
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.warmBeige,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            
            // 应用名称
            Text(
              appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            
            // 包名
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      packageName,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      _copyToClipboard(packageName);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingLG),
            
            // 使用示例
            const Text(
              '使用示例',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: AppTheme.primaryBeige,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '打开$appName，给张三发消�?,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + AppTheme.spacingMD),
          ],
        ),
      ),
    );
  }
}
