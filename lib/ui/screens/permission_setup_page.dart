import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';

/// 权限检查页面
/// 用户必须完成所有授权才能使用应用
class PermissionSetupPage extends StatefulWidget {
  const PermissionSetupPage({super.key});

  @override
  State<PermissionSetupPage> createState() => _PermissionSetupPageState();
}

class _PermissionSetupPageState extends State<PermissionSetupPage> {
  final DeviceController _deviceController = DeviceController();
  
  bool _shizukuInstalled = false;
  bool _shizukuRunning = false;
  bool _shizukuAuthorized = false;
  bool _accessibilityEnabled = false;
  bool _overlayPermission = false;
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }
  
  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      _shizukuInstalled = await _deviceController.isShizukuInstalled();
      _shizukuRunning = await _deviceController.isShizukuRunning();
      _shizukuAuthorized = await _deviceController.isShizukuAuthorized();
      _accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
      _overlayPermission = await _deviceController.checkOverlayPermission();
    } catch (e) {
      debugPrint('Check permissions error: $e');
    }
    
    setState(() => _isLoading = false);
    
    // 如果所有权限都满足，自动进入主页
    if (_allPermissionsGranted) {
      _navigateToHome();
    }
  }
  
  bool get _allPermissionsGranted {
    return _shizukuAuthorized && _accessibilityEnabled && _overlayPermission;
  }
  
  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('权限设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    '请完成以下授权',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AutoGLM 需要这些权限来控制您的设备',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 32),
                  
                  // 权限列表
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPermissionCard(
                          title: 'Shizuku 授权',
                          subtitle: _shizukuInstalled
                              ? (_shizukuRunning
                                  ? (_shizukuAuthorized ? '已授权 ✓' : '点击授权')
                                  : '请先启动 Shizuku 服务')
                              : '请先安装 Shizuku',
                          icon: Icons.security,
                          isGranted: _shizukuAuthorized,
                          onTap: () => _handleShizukuSetup(),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildPermissionCard(
                          title: '无障碍服务',
                          subtitle: _accessibilityEnabled
                              ? '已启用 ✓'
                              : '点击前往设置',
                          icon: Icons.accessibility_new,
                          isGranted: _accessibilityEnabled,
                          onTap: () => _handleAccessibilitySetup(),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildPermissionCard(
                          title: '悬浮窗权限',
                          subtitle: _overlayPermission
                              ? '已授权 ✓'
                              : '点击前往设置',
                          icon: Icons.picture_in_picture,
                          isGranted: _overlayPermission,
                          onTap: () => _handleOverlayPermission(),
                        ),
                      ],
                    ),
                  ),
                  
                  // 底部按钮
                  const SizedBox(height: 24),
                  
                  // 刷新按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkPermissions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新权限状态'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 继续按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _allPermissionsGranted ? _navigateToHome : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey[700],
                      ),
                      child: Text(
                        _allPermissionsGranted ? '进入应用' : '请完成所有授权',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Card(
      color: isGranted 
          ? AppTheme.primaryColor.withOpacity(0.1)
          : AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted ? AppTheme.primaryColor : Colors.transparent,
          width: isGranted ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? AppTheme.primaryColor : Colors.grey[400],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isGranted 
                            ? AppTheme.primaryColor 
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isGranted ? AppTheme.primaryColor : Colors.grey[600],
                size: isGranted ? 28 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleShizukuSetup() async {
    if (!_shizukuInstalled) {
      // 打开Shizuku下载页面
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请从Google Play或GitHub下载安装Shizuku')),
      );
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
