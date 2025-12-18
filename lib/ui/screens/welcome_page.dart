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
      icon: Icons.smart_toy_outlined,
      title: 'AutoZi 智能助手',
      description: 'AI 驱动的手机自动化助手\n自然语言，一语即达',
      type: _PageType.intro,
    ),
    _WelcomePageData(
      icon: Icons.auto_awesome_outlined,
      title: '智能理解',
      description: '描述您的需求\nAI 自动规划并执行操作',
      type: _PageType.intro,
    ),
    _WelcomePageData(
      icon: Icons.vpn_key_outlined,
      title: '配置 API 密钥',
      description: '连接 AutoGLM 服务的密钥',
      type: _PageType.apiKey,
    ),
    _WelcomePageData(
      icon: Icons.shield_outlined,
      title: '权限配置',
      description: '授予必要权限以接管操作',
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
  
  bool get _allPermissionsGranted => _accessibilityEnabled && _overlayPermission && _shizukuAuthorized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮 (仅非强制页面)
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < 2 
                  ? TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textHint,
                      ),
                      child: const Text('跳过'),
                    )
                  : const SizedBox(height: 48),
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
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryBlack : AppTheme.grey200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _getButtonAction(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlack,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: AppTheme.grey200,
                  ),
                  child: Text(
                    _getButtonText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      return _allPermissionsGranted ? '开始探索' : '请完成所有配置';
    }
    return _currentPage < _pages.length - 1 ? '继续' : '开始使用';
  }
  
  VoidCallback? _getButtonAction() {
    final page = _pages[_currentPage];
    if (page.type == _PageType.permission) {
      return _allPermissionsGranted ? _complete : null;
    }
    if (page.type == _PageType.apiKey) {
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
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.grey100),
            ),
            child: Icon(
              page.icon,
              size: 56,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlack,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildApiKeyPage(_WelcomePageData page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(page.icon, size: 64, color: AppTheme.primaryBlack),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          TextField(
            controller: _apiKeyController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: '请输入智谱 API Key',
              prefixIcon: const Icon(Icons.key_outlined, size: 20, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryBlack),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
            obscureText: true,
          ),
          
          const SizedBox(height: 24),
          
          TextButton.icon(
            onPressed: _openApiKeyPage,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('获取 API Key'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlack,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionPage(_WelcomePageData page) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 24),
        Text(
          page.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          page.description,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        
        _buildPermissionCard(
          title: '无障碍服务',
          subtitle: _accessibilityEnabled ? '已就绪' : '核心操控能力',
          icon: Icons.accessibility_new_outlined,
          isGranted: _accessibilityEnabled,
          onTap: () => _handleAccessibilitySetup(),
        ),
        const SizedBox(height: 16),
        _buildPermissionCard(
          title: '悬浮窗权限',
          subtitle: _overlayPermission ? '已就绪' : '任务状态显示',
          icon: Icons.layers_outlined,
          isGranted: _overlayPermission,
          onTap: () => _handleOverlayPermission(),
        ),
        const SizedBox(height: 16),
        _buildPermissionCard(
          title: 'Shizuku 服务',
          subtitle: _shizukuAuthorized ? '已就绪' : '高级输入与控制',
          icon: Icons.adb_outlined,
          isGranted: _shizukuAuthorized,
          onTap: () => _showShizukuGuide(),
        ),
         const SizedBox(height: 24),
         Center(
          child: Text(
           _allPermissionsGranted 
              ? '所有配置已就绪' 
              : '需授予所有权限以继续',
            style: TextStyle(
              fontSize: 13,
              color: _allPermissionsGranted ? AppTheme.primaryBlack : AppTheme.textHint,
              fontWeight: FontWeight.w500,
            ),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isGranted ? AppTheme.grey50 : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? Colors.transparent : AppTheme.grey200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted ? Colors.white : AppTheme.primaryBlack,
                borderRadius: BorderRadius.circular(12),
                border: isGranted ? Border.all(color: AppTheme.grey200) : null,
              ),
              child: Icon(
                isGranted ? Icons.check : icon,
                color: isGranted ? AppTheme.primaryBlack : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isGranted ? AppTheme.textSecondary : AppTheme.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isGranted ? AppTheme.textHint : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              const Icon(Icons.arrow_forward, size: 20, color: AppTheme.primaryBlack),
          ],
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
                const Icon(Icons.security, color: AppTheme.primaryBlack),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.grey200),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlack,
                      foregroundColor: Colors.white,
                    ),
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
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlack,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                  style: const TextStyle(
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
  final _PageType type;

  _WelcomePageData({
    required this.icon,
    required this.title,
    required this.description,
    this.type = _PageType.intro,
  });
}
