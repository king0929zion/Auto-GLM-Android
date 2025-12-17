import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../../config/settings_repository.dart';
import '../../services/device/device_controller.dart';

/// 欢迎/引导页面
/// 首次运行时显示，引导用户完成初始配置
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _apiKeyController = TextEditingController();
  int _currentPage = 0;
  
  // 权限状态
  final DeviceController _deviceController = DeviceController();
  bool _accessibilityEnabled = false;
  bool _overlayPermission = false;
  bool _shizukuAuthorized = false;
  bool _shizukuInstalled = false;
  bool _isCheckingPermissions = false;
  Timer? _permissionCheckTimer;
  
  final List<_WelcomePageData> _pages = [
    _WelcomePageData(
      icon: Icons.smart_toy,
      title: '欢迎使用 AutoZi',
      description: 'AI驱动的手机自动化助手\n让您用自然语言控制手机',
      color: AppTheme.accentOrange,
      type: _PageType.intro,
    ),
    _WelcomePageData(
      icon: Icons.auto_awesome,
      title: '智能理解，自动执行',
      description: '只需描述您想要完成的任务\nAI会自动分析屏幕并执行操作',
      color: AppTheme.accentOrangeDeep,
      type: _PageType.intro,
    ),
    _WelcomePageData(
      icon: Icons.key,
      title: '配置 API 密钥',
      description: '请输入您的智谱 API Key\n用于连接 AutoGLM 服务',
      color: AppTheme.info,
      type: _PageType.apiKey,
    ),
    _WelcomePageData(
      icon: Icons.accessibility_new,
      title: '权限配置',
      description: '开启必要权限后即可开始使用',
      color: AppTheme.success,
      type: _PageType.permission,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }
  
  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }
  
  Future<void> _checkPermissions() async {
    if (_isCheckingPermissions) return;
    _isCheckingPermissions = true;
    
    try {
      _accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
      _overlayPermission = await _deviceController.checkOverlayPermission();
      _shizukuInstalled = await _deviceController.isShizukuInstalled();
      _shizukuAuthorized = await _deviceController.isShizukuAuthorized();
    } catch (e) {
      debugPrint('Check permissions error: $e');
    }
    
    if (mounted) {
      setState(() {});
      _isCheckingPermissions = false;
    }
  }
  
  bool get _allPermissionsGranted => _accessibilityEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text('跳过'),
              ),
            ),
            
            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                  // 当进入权限页面时，启动定时检查
                  if (_pages[page].type == _PageType.permission) {
                    _startPermissionCheck();
                  } else {
                    _stopPermissionCheck();
                  }
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // 页面指示器
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.accentOrange
                          : AppTheme.warmBeige,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _getButtonAction(),
                  child: Text(_getButtonText()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _startPermissionCheck() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkPermissions();
      }
    });
  }
  
  void _stopPermissionCheck() {
    _permissionCheckTimer?.cancel();
  }
  
  String _getButtonText() {
    final page = _pages[_currentPage];
    if (page.type == _PageType.permission) {
      return _allPermissionsGranted ? '开始使用' : '请完成权限配置';
    }
    return _currentPage < _pages.length - 1 ? '下一步' : '开始使用';
  }
  
  VoidCallback? _getButtonAction() {
    final page = _pages[_currentPage];
    if (page.type == _PageType.permission) {
      return _allPermissionsGranted ? _complete : null;
    }
    if (page.type == _PageType.apiKey && _currentPage < _pages.length - 1) {
      // API Key 页面，需要在保存后才能下一步
      return _saveApiKeyAndNext;
    }
    return _currentPage < _pages.length - 1 ? _nextPage : _complete;
  }
  
  Future<void> _saveApiKeyAndNext() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await SettingsRepository.instance.setApiKey(apiKey);
    }
    _nextPage();
  }

  Widget _buildPage(_WelcomePageData page) {
    switch (page.type) {
      case _PageType.apiKey:
        return _buildApiKeyPage(page);
      case _PageType.permission:
        return _buildPermissionPage(page);
      default:
        return _buildIntroPage(page);
    }
  }
  
  Widget _buildIntroPage(_WelcomePageData page) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // 标题
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // 描述
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildApiKeyPage(_WelcomePageData page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 48,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 标题
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          // 描述
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // API Key 输入框
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: '智谱 API Key',
                    hintText: '请输入您的 API Key',
                    prefixIcon: Icon(Icons.vpn_key),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  obscureText: true,
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
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          Text(
            '提示：您可以稍后在设置中配置 API Key',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionPage(_WelcomePageData page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          // 标题
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 40,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 必需权限标题
          _buildSectionTitle('必需权限', Icons.check_circle, AppTheme.accentOrange),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          // 无障碍服务
          _buildPermissionCard(
            title: '无障碍服务',
            subtitle: _accessibilityEnabled
                ? '已启用 - 用于模拟点击、滑动和输入'
                : '点击前往设置开启（必需）',
            icon: Icons.accessibility_new,
            isGranted: _accessibilityEnabled,
            isRequired: true,
            onTap: () => _handleAccessibilitySetup(),
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 可选权限标题
          _buildSectionTitle('可选权限（增强体验）', Icons.star_outline, AppTheme.textHint),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          _buildPermissionCard(
            title: '悬浮窗权限',
            subtitle: _overlayPermission
                ? '已授权 - 用于显示任务执行状态'
                : '未授权（不影响核心功能）',
            icon: Icons.picture_in_picture,
            isGranted: _overlayPermission,
            isRequired: false,
            onTap: () => _handleOverlayPermission(),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          _buildPermissionCard(
            title: 'Shizuku（推荐）',
            subtitle: _shizukuAuthorized
                ? '已授权 - 提供更可靠的输入能力'
                : (_shizukuInstalled ? '点击授权' : '未安装（可跳过）'),
            icon: Icons.security,
            isGranted: _shizukuAuthorized,
            isRequired: false,
            onTap: () => _showShizukuGuide(),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // Shizuku 优势说明
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.info.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.info),
                    const SizedBox(width: 8),
                    Text(
                      'Shizuku 的优势',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 更可靠的文本输入（特别是微信等应用）\n'
                  '• 支持剪贴板+粘贴的输入方式\n'
                  '• 不依赖 ADB Keyboard 等额外应用\n'
                  '• 提供系统级截图能力的备选方案',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 进度提示
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: _allPermissionsGranted 
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.warmBeige.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              children: [
                Icon(
                  _allPermissionsGranted ? Icons.check_circle : Icons.info_outline,
                  color: _allPermissionsGranted ? AppTheme.success : AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    _allPermissionsGranted 
                        ? '权限配置完成，可以开始使用了！'
                        : '请至少开启无障碍服务以正常使用应用',
                    style: TextStyle(
                      color: _allPermissionsGranted ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return Card(
      color: isGranted 
          ? AppTheme.success.withOpacity(0.1)
          : AppTheme.surfaceWhite,
      elevation: isGranted ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted ? AppTheme.success : AppTheme.warmBeige,
          width: isGranted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppTheme.success.withOpacity(0.2)
                      : AppTheme.warmBeige.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? AppTheme.success : AppTheme.textSecondary,
                  size: 24,
                ),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 6),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isGranted ? AppTheme.success : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isGranted ? AppTheme.success : AppTheme.textHint,
                size: isGranted ? 24 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showShizukuGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: AppTheme.accentOrange),
                const SizedBox(width: 12),
                const Text(
                  'Shizuku 配置指南',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildGuideStep('1', '安装 Shizuku', 
              '从 Google Play 或 GitHub 下载安装 Shizuku 应用'),
            _buildGuideStep('2', '启动 Shizuku 服务',
              '打开 Shizuku 应用，按照提示通过 ADB 或无线调试启动服务'),
            _buildGuideStep('3', '授权 AutoGLM',
              '返回本应用，点击 Shizuku 权限卡片进行授权'),
            
            const SizedBox(height: 20),
            
            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('稍后配置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (_shizukuInstalled) {
                        await _deviceController.requestShizukuPermission();
                      } else {
                        // 打开 Shizuku 下载页面
                        final uri = Uri.parse('https://shizuku.rikka.app/');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                      Future.delayed(const Duration(seconds: 1), _checkPermissions);
                    },
                    child: Text(_shizukuInstalled ? '立即授权' : '下载 Shizuku'),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGuideStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
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
  
  Future<void> _handleAccessibilitySetup() async {
    await _deviceController.openAccessibilitySettings();
    await Future.delayed(const Duration(seconds: 2));
    _checkPermissions();
  }
  
  Future<void> _handleOverlayPermission() async {
    final success = await _deviceController.openOverlaySettings();
    if (success) {
      await Future.delayed(const Duration(seconds: 2));
      _checkPermissions();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请在设置中授予悬浮窗权限')),
        );
      }
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    _complete();
  }

  void _complete() async {
    // 保存 API Key
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await SettingsRepository.instance.setApiKey(apiKey);
    }
    
    await SettingsRepository.instance.setFirstRunCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}

enum _PageType {
  intro,
  apiKey,
  permission,
}

class _WelcomePageData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final _PageType type;

  _WelcomePageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.type = _PageType.intro,
  });
}
