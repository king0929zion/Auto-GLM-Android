import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../../config/settings_repository.dart';
import '../../services/device/device_controller.dart';

/// 欢迎页面 - 极简引导流程
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _apiKeyController = TextEditingController();
  int _currentPage = 0;

  final DeviceController _deviceController = DeviceController();
  bool _accessibilityEnabled = false;
  bool _overlayPermission = false;
  bool _shizukuAuthorized = false;
  bool _shizukuInstalled = false;
  bool _isCheckingPermissions = false;
  Timer? _permissionCheckTimer;

  final List<_PageData> _pages = [
    _PageData(
      icon: Icons.auto_awesome_rounded,
      title: 'AutoZi',
      description: 'AI-powered phone automation\nSpeak naturally, act instantly',
      type: _PageType.intro,
    ),
    _PageData(
      icon: Icons.psychology_rounded,
      title: 'Smart Execution',
      description: 'Describe what you need\nAI plans and executes for you',
      type: _PageType.intro,
    ),
    _PageData(
      icon: Icons.key_rounded,
      title: 'API Key',
      description: 'Connect to AutoGLM service',
      type: _PageType.apiKey,
    ),
    _PageData(
      icon: Icons.shield_rounded,
      title: 'Permissions',
      description: 'Grant access to enable automation',
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

  bool get _allPermissionsGranted =>
      _accessibilityEnabled && _overlayPermission && _shizukuAuthorized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < 2
                  ? Padding(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      child: GestureDetector(
                        onTap: _skip,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: AppTheme.fontSize14,
                            color: AppTheme.grey500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(height: 52),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  if (_pages[page].type == _PageType.permission) {
                    _startPermissionCheck();
                  } else {
                    _stopPermissionCheck();
                  }
                },
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: AppTheme.durationNormal,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.black : AppTheme.grey200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space24,
                0,
                AppTheme.space24,
                AppTheme.space32,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _getButtonAction(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonAction() == null
                        ? AppTheme.grey200
                        : AppTheme.black,
                    disabledBackgroundColor: AppTheme.grey200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    _getButtonText(),
                    style: TextStyle(
                      fontSize: AppTheme.fontSize15,
                      fontWeight: FontWeight.w600,
                      color: _getButtonAction() == null
                          ? AppTheme.grey400
                          : AppTheme.white,
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

  Widget _buildPage(_PageData page) {
    switch (page.type) {
      case _PageType.apiKey:
        return _buildApiKeyPage(page);
      case _PageType.permission:
        return _buildPermissionPage(page);
      default:
        return _buildIntroPage(page);
    }
  }

  /// 介绍页 - 极简居中布局
  Widget _buildIntroPage(_PageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 极简圆形图标
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 44,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: AppTheme.space40),
          
          Text(
            page.title,
            style: const TextStyle(
              fontSize: AppTheme.fontSize28,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space12),
          
          Text(
            page.description,
            style: const TextStyle(
              fontSize: AppTheme.fontSize15,
              color: AppTheme.grey500,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// API Key 页面
  Widget _buildApiKeyPage(_PageData page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space32),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.space40),
          
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 36,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: AppTheme.space32),
          
          Text(
            page.title,
            style: const TextStyle(
              fontSize: AppTheme.fontSize24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          
          Text(
            page.description,
            style: const TextStyle(
              fontSize: AppTheme.fontSize14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space40),

          // API Key 输入框
          TextField(
            controller: _apiKeyController,
            style: const TextStyle(fontSize: AppTheme.fontSize15),
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter your Zhipu API Key',
              prefixIcon: const Icon(
                Icons.key_rounded,
                size: 20,
                color: AppTheme.grey400,
              ),
              filled: true,
              fillColor: AppTheme.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: const BorderSide(color: AppTheme.black, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space16,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space20),

          GestureDetector(
            onTap: _openApiKeyPage,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: AppTheme.space6),
                const Text(
                  'Get API Key',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 权限页面
  Widget _buildPermissionPage(_PageData page) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
      children: [
        const SizedBox(height: AppTheme.space24),
        
        Text(
          page.title,
          style: const TextStyle(
            fontSize: AppTheme.fontSize28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        
        Text(
          page.description,
          style: const TextStyle(
            fontSize: AppTheme.fontSize15,
            color: AppTheme.grey500,
          ),
        ),
        const SizedBox(height: AppTheme.space32),

        _PermissionCard(
          icon: Icons.accessibility_new_rounded,
          title: 'Accessibility',
          subtitle: _accessibilityEnabled ? 'Ready' : 'Core control capability',
          isGranted: _accessibilityEnabled,
          onTap: _handleAccessibilitySetup,
        ),
        const SizedBox(height: AppTheme.space12),
        
        _PermissionCard(
          icon: Icons.layers_rounded,
          title: 'Overlay',
          subtitle: _overlayPermission ? 'Ready' : 'Task status display',
          isGranted: _overlayPermission,
          onTap: _handleOverlayPermission,
        ),
        const SizedBox(height: AppTheme.space12),
        
        _PermissionCard(
          icon: Icons.terminal_rounded,
          title: 'Shizuku',
          subtitle: _shizukuAuthorized ? 'Ready' : 'Advanced input & control',
          isGranted: _shizukuAuthorized,
          onTap: _showShizukuGuide,
        ),
        
        const SizedBox(height: AppTheme.space32),
        
        Center(
          child: Text(
            _allPermissionsGranted
                ? 'All set! Ready to go'
                : 'Grant all permissions to continue',
            style: TextStyle(
              fontSize: AppTheme.fontSize13,
              color: _allPermissionsGranted ? AppTheme.grey900 : AppTheme.grey500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _startPermissionCheck() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) _checkPermissions();
    });
  }

  void _stopPermissionCheck() {
    _permissionCheckTimer?.cancel();
  }

  String _getButtonText() {
    final page = _pages[_currentPage];
    if (page.type == _PageType.permission) {
      return _allPermissionsGranted ? 'Get Started' : 'Complete all permissions';
    }
    return _currentPage < _pages.length - 1 ? 'Continue' : 'Get Started';
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
    }
  }

  void _showShizukuGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShizukuGuideSheet(
        isInstalled: _shizukuInstalled,
        onAction: () async {
          Navigator.pop(context);
          if (_shizukuInstalled) {
            await _deviceController.requestShizukuPermission();
          } else {
            final uri = Uri.parse('https://shizuku.rikka.app/');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
          Future.delayed(const Duration(seconds: 1), _checkPermissions);
        },
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: AppTheme.durationNormal,
      curve: AppTheme.curveDefault,
    );
  }

  void _skip() => _complete();

  void _complete() async {
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

// ============================================
// 组件
// ============================================

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        padding: const EdgeInsets.all(AppTheme.space16),
        decoration: BoxDecoration(
          color: isGranted ? AppTheme.grey50 : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isGranted ? Colors.transparent : AppTheme.grey150,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isGranted ? AppTheme.white : AppTheme.black,
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                border: isGranted ? Border.all(color: AppTheme.grey200) : null,
              ),
              child: Icon(
                isGranted ? Icons.check_rounded : icon,
                size: 22,
                color: isGranted ? AppTheme.black : AppTheme.white,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize15,
                      fontWeight: FontWeight.w600,
                      color: isGranted ? AppTheme.grey500 : AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize13,
                      color: isGranted ? AppTheme.grey400 : AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: AppTheme.grey900,
              ),
          ],
        ),
      ),
    );
  }
}

class _ShizukuGuideSheet extends StatelessWidget {
  final bool isInstalled;
  final VoidCallback onAction;

  const _ShizukuGuideSheet({
    required this.isInstalled,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius20)),
      ),
      padding: const EdgeInsets.all(AppTheme.space24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.grey50,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    size: 20,
                    color: AppTheme.grey700,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                const Text(
                  'Shizuku Setup',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space24),

            _GuideStep(number: '1', title: 'Install Shizuku', description: 'Download from Google Play or GitHub'),
            _GuideStep(number: '2', title: 'Start Service', description: 'Enable via ADB or Wireless Debugging'),
            _GuideStep(number: '3', title: 'Authorize App', description: 'Return here and grant permission'),

            const SizedBox(height: AppTheme.space24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.grey600,
                      side: const BorderSide(color: AppTheme.grey200),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(isInstalled ? 'Authorize' : 'Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: AppTheme.fontSize11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSize14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSize12,
                    color: AppTheme.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// 数据类
// ============================================

enum _PageType { intro, apiKey, permission }

class _PageData {
  final IconData icon;
  final String title;
  final String description;
  final _PageType type;

  _PageData({
    required this.icon,
    required this.title,
    required this.description,
    this.type = _PageType.intro,
  });
}
