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
      await SettingsRepository.instance.setAutoglmApiKey(apiKey);
    }
    _nextPage();
  }

  // ... (intermediate code)

  void _complete() async {
    // 保存 API Key
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await SettingsRepository.instance.setAutoglmApiKey(apiKey);
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
