import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';

/// 权限检查页面
/// 必需：无障碍服务
/// 可选：悬浮窗（用于显示任务状态）
/// 可选：Shizuku（用于增强功能）
class PermissionSetupPage extends StatefulWidget {
  const PermissionSetupPage({super.key});

  @override
  State<PermissionSetupPage> createState() => _PermissionSetupPageState();
}

class _PermissionSetupPageState extends State<PermissionSetupPage>
    with WidgetsBindingObserver {
  final DeviceController _deviceController = DeviceController();

  // Shizuku 状态（可选）
  bool _shizukuInstalled = false;
  bool _shizukuRunning = false;
  bool _shizukuAuthorized = false;

  // 必需和可选权限
  bool _accessibilityEnabled = false;
  bool _overlayPermission = false;

  bool _isLoading = true;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    // 启动定时检查（每2秒检查一次权限状态）
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkPermissions();
      }
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台返回时，立即检查权限
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    // 首次检查时显示加载状态，后续静默检查
    if (_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Shizuku 状态检查（可选）
      _shizukuInstalled = await _deviceController.isShizukuInstalled();
      _shizukuRunning = await _deviceController.isShizukuRunning();
      _shizukuAuthorized = await _deviceController.isShizukuAuthorized();

      // 必需权限检查
      _accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
      _overlayPermission = await _deviceController.checkOverlayPermission();
    } catch (e) {
      debugPrint('Check permissions error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);

      // 如果必需权限都满足，自动进入主页
      if (_requiredPermissionsGranted && !_hasNavigated) {
        _navigateToHome();
      }
    }
  }

  // 必需权限：无障碍服务、悬浮窗、Shizuku
  bool get _requiredPermissionsGranted {
    // Shizuku 也作为必需权限，除非用户真的无法安装（但这里我们强制要求）
    return _accessibilityEnabled && _overlayPermission && _shizukuAuthorized;
  }

  bool _hasNavigated = false;

  void _navigateToHome() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // 取消定时器
    _autoCheckTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('权限配置',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlack))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      // Header Phase
                      const Text(
                        '完成设置以开始使用',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlack,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AutoZi 需要完全控制您的设备以执行自动化任务。请授予以下所有权限。',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Progress Phase
                      _buildProgressIndicator(),
                      
                      const SizedBox(height: 40),

                      // Permissions List
                      _buildPermissionCard(
                        title: '无障碍服务',
                        subtitle: _accessibilityEnabled
                            ? '已就绪'
                            : '用于模拟点击和滑动操作',
                        icon: Icons.accessibility_new,
                        isGranted: _accessibilityEnabled,
                        onTap: () => _handleAccessibilitySetup(),
                      ),
                      
                      const SizedBox(height: 16),

                      _buildPermissionCard(
                        title: '悬浮窗权限',
                        subtitle: _overlayPermission
                            ? '已就绪'
                            : '用于显示任务状态面板',
                        icon: Icons.layers_outlined,
                        isGranted: _overlayPermission,
                        onTap: () => _handleOverlayPermission(),
                      ),

                      const SizedBox(height: 16),
                      
                      _buildPermissionCard(
                        title: 'Shizuku 服务',
                        subtitle: _shizukuAuthorized
                            ? '已就绪'
                            : (_shizukuRunning ? '点击授权' : '请启动 Shizuku 服务'),
                        icon: Icons.adb_rounded,
                        isGranted: _shizukuAuthorized,
                        onTap: () => _handleShizukuSetup(),
                      ),
                    ],
                  ),
                ),

                // Bottom Action
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: AppTheme.grey200.withOpacity(0.5))),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              _requiredPermissionsGranted ? _navigateToHome : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlack,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: AppTheme.grey200,
                            disabledForegroundColor: AppTheme.grey400,
                          ),
                          child: Text(
                            _requiredPermissionsGranted ? '开始探索' : '请完成所有配置',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 实时检测提示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '实时检测中',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    int grantedCount = 0;
    if (_accessibilityEnabled) grantedCount++;
    if (_overlayPermission) grantedCount++;
    if (_shizukuAuthorized) grantedCount++;
    const totalCount = 3;
    final progress = grantedCount / totalCount;

    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.grey100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryBlack),
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                grantedCount == totalCount ? '配置完成' : '待处理项 $grantedCount/$totalCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                grantedCount == totalCount 
                  ? '您可以开始使用 AutoZi 了' 
                  : '请依次点击下方卡片完成授权',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isGranted ? AppTheme.grey50 : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGranted ? Colors.transparent : AppTheme.grey200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted ? Colors.white : AppTheme.primaryBlack,
                borderRadius: BorderRadius.circular(14),
                border: isGranted ? Border.all(color: AppTheme.grey200) : null,
              ),
              child: Icon(
                isGranted ? Icons.check : icon,
                color: isGranted ? AppTheme.primaryBlack : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
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
              const Icon(Icons.arrow_forward, color: AppTheme.primaryBlack, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShizukuSetup() async {
    if (!_shizukuInstalled) {
      // 打开Shizuku下载页面
      final uri = Uri.parse('https://shizuku.rikka.app/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!_shizukuRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请打开Shizuku应用并启动服务')),
      );
      return;
    }

    // 请求授权
    await _deviceController.requestShizukuPermission();
    await Future.delayed(const Duration(seconds: 1));
    _checkPermissions();
  }

  Future<void> _handleAccessibilitySetup() async {
    await _deviceController.openAccessibilitySettings();
    // 返回后刷新状态
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
}
