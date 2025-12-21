import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';

/// 权限配置页面
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  final DeviceController _deviceController = DeviceController();
  Timer? _checkTimer;
  
  bool _accessibilityEnabled = false;
  bool _shizukuInstalled = false;
  bool _shizukuRunning = false;
  bool _shizukuAuthorized = false;
  bool _batteryOptimizationIgnored = false;
  bool _autoZiImeEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _checkAllPermissions();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    try {
      _accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
      _shizukuInstalled = await _deviceController.isShizukuInstalled();
      _shizukuRunning = await _deviceController.isShizukuRunning();
      _shizukuAuthorized = await _deviceController.isShizukuAuthorized();
      _batteryOptimizationIgnored = await _deviceController.isIgnoringBatteryOptimizations();
      _autoZiImeEnabled = await _deviceController.isAutoZiImeEnabled();
    } catch (e) {
      debugPrint('Check permissions error: $e');
    }
    if (mounted) setState(() {});
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
          '权限配置',
          style: TextStyle(
            color: AppTheme.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('必需权限'),
          const SizedBox(height: 12),
          _buildPermissionCard(
            title: '无障碍服务',
            subtitle: 'AI 执行屏幕操作所需',
            isEnabled: _accessibilityEnabled,
            isRequired: true,
            onTap: () => _deviceController.openAccessibilitySettings(),
          ),
          const SizedBox(height: 12),
          _buildPermissionCard(
            title: 'AutoZi 输入法',
            subtitle: '用于输入文字',
            isEnabled: _autoZiImeEnabled,
            isRequired: true,
            onTap: () => _deviceController.openInputMethodSettings(),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('可选权限'),
          const SizedBox(height: 12),
          _buildPermissionCard(
            title: '忽略电池优化',
            subtitle: '防止后台被系统杀死',
            isEnabled: _batteryOptimizationIgnored,
            isRequired: false,
            onTap: () => _deviceController.requestIgnoreBatteryOptimization(),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('高级权限 (Shizuku)'),
          const SizedBox(height: 8),
          Text(
            '提供更强大的自动化能力，需要 ADB 调试',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.grey500,
            ),
          ),
          const SizedBox(height: 12),
          _buildShizukuCard(),
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

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.grey50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEnabled ? AppTheme.success.withOpacity(0.1) : AppTheme.grey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEnabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: isEnabled ? AppTheme.success : AppTheme.grey400,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey800,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '必需',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.grey500,
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

  Widget _buildShizukuCard() {
    String status;
    Color statusColor;
    
    if (!_shizukuInstalled) {
      status = '未安装';
      statusColor = AppTheme.grey500;
    } else if (!_shizukuRunning) {
      status = '未运行';
      statusColor = AppTheme.warning;
    } else if (!_shizukuAuthorized) {
      status = '未授权';
      statusColor = AppTheme.warning;
    } else {
      status = '已就绪';
      statusColor = AppTheme.success;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _shizukuAuthorized ? AppTheme.success.withOpacity(0.1) : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.developer_mode_rounded,
                  color: _shizukuAuthorized ? AppTheme.success : AppTheme.grey400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shizuku',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_shizukuInstalled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _deviceController.openShizukuDownload(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: BorderSide(color: AppTheme.accent.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('下载 Shizuku'),
              ),
            ),
          ] else if (!_shizukuAuthorized && _shizukuRunning) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _deviceController.requestShizukuPermission(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('授权'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
