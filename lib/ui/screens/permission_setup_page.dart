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

  // 必需权限：无障碍服务
  bool get _requiredPermissionsGranted {
    return _accessibilityEnabled;
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
        title: const Text('权限设置',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlack))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '配置必要权限',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AutoZi 需要以下权限来自动控制您的设备',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 进度提示
                  _buildProgressIndicator(),

                  const SizedBox(height: 32),

                  // 权限列表
                  Expanded(
                    child: ListView(
                      children: [
                        // 必需权限标题
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            '必需权限',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlack,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),

                        _buildPermissionCard(
                          title: '无障碍服务',
                          subtitle: _accessibilityEnabled
                              ? '已启用 - 用于模拟点击、滑动和输入'
                              : '点击前往设置开启',
                          icon: Icons.accessibility_new,
                          isGranted: _accessibilityEnabled,
                          isRequired: true,
                          onTap: () => _handleAccessibilitySetup(),
                        ),

                        const SizedBox(height: 32),

                        // 可选权限标题
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            '可选权限（增强体验）',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlack,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),

                        _buildPermissionCard(
                          title: '悬浮窗权限',
                          subtitle: _overlayPermission
                              ? '已授权 - 用于显示任务状态'
                              : '未授权（不影响任务执行）',
                          icon: Icons.picture_in_picture,
                          isGranted: _overlayPermission,
                          isRequired: false,
                          onTap: () => _handleOverlayPermission(),
                        ),

                        const SizedBox(height: 12),

                        _buildPermissionCard(
                          title: 'Shizuku（推荐）',
                          subtitle: _shizukuInstalled
                              ? (_shizukuRunning
                                  ? (_shizukuAuthorized
                                      ? '已授权 - 提供更可靠的输入能力'
                                      : '点击授权')
                                  : '请先启动 Shizuku 服务')
                              : '未安装（可跳过）',
                          icon: Icons.security,
                          isGranted: _shizukuAuthorized,
                          isRequired: false,
                          onTap: () => _handleShizukuSetup(),
                        ),

                        const SizedBox(height: 16),

                        // Shizuku 优势说明
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.grey50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lightbulb_outline,
                                      size: 16, color: AppTheme.primaryBlack),
                                  SizedBox(width: 8),
                                  Text(
                                    'Shizuku 的优势',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryBlack,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• 更可靠的文本输入（特别是微信等应用）\n'
                                '• 支持剪贴板+粘贴的输入方式\n'
                                '• 不依赖 ADB Keyboard 等额外应用',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 底部按钮
                  const SizedBox(height: 24),

                  // 继续按钮
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
                          borderRadius: BorderRadius.circular(28),
                        ),
                        disabledBackgroundColor: AppTheme.grey300,
                      ),
                      child: Text(
                        _requiredPermissionsGranted ? '开始使用' : '请完成必需权限',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 实时检测提示
                  const Center(
                    child: Text(
                      '已启用实时权限检测',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    int grantedCount = 0;
    if (_accessibilityEnabled) grantedCount++;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          // 进度环
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: grantedCount / 1,
                  backgroundColor: AppTheme.grey100,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryBlack),
                  strokeWidth: 5,
                ),
                Text(
                  '$grantedCount/1',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 状态文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _requiredPermissionsGranted ? '权限配置完成' : '正在配置权限...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _requiredPermissionsGranted ? '所有必需权限已就绪' : '请按照提示开启无障碍服务',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_requiredPermissionsGranted)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
        ],
      ),
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
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? AppTheme.grey200
                : (isRequired ? AppTheme.primaryBlack : AppTheme.grey200),
            width: isRequired && !isGranted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted ? AppTheme.grey100 : AppTheme.primaryBlack,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isGranted ? AppTheme.primaryBlack : Colors.white,
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
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isRequired && !isGranted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                      color:
                          isGranted ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(Icons.check, color: AppTheme.success, size: 20)
            else
              const Icon(Icons.arrow_forward_ios,
                  color: AppTheme.grey300, size: 16),
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
