import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../services/shizuku/shizuku_service.dart';

/// Shizuku设置和引导页�?
class ShizukuSetupPage extends StatefulWidget {
  const ShizukuSetupPage({super.key});

  @override
  State<ShizukuSetupPage> createState() => _ShizukuSetupPageState();
}

class _ShizukuSetupPageState extends State<ShizukuSetupPage> {
  ShizukuStatus _status = ShizukuStatus.unknown;
  bool _isChecking = false;
  String? _version;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    
    try {
      // 这里会调用原生层检查Shizuku状�?
      // 目前使用模拟数据
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 实际实现会从Platform Channel获取
      setState(() {
        _status = ShizukuStatus.notAuthorized; // 模拟状�?
        _version = '13.1.5';
      });
    } catch (e) {
      setState(() {
        _status = ShizukuStatus.notInstalled;
      });
    } finally {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Shizuku 设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isChecking ? null : _checkStatus,
            tooltip: '刷新状�?,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // 状态卡�?
          _buildStatusCard(),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 设置步骤
          _buildSetupSteps(),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // 常见问题
          _buildFAQ(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDesc;
    
    switch (_status) {
      case ShizukuStatus.authorized:
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        statusText = '已就�?;
        statusDesc = 'Shizuku 服务运行正常，可以正常使�?;
        break;
      case ShizukuStatus.notAuthorized:
        statusColor = AppTheme.warning;
        statusIcon = Icons.warning_amber;
        statusText = '需要授�?;
        statusDesc = 'Shizuku 服务已运行，但需要本应用授权';
        break;
      case ShizukuStatus.notStarted:
        statusColor = AppTheme.error;
        statusIcon = Icons.error_outline;
        statusText = '未启�?;
        statusDesc = 'Shizuku 已安装，但服务未启动';
        break;
      case ShizukuStatus.notInstalled:
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel_outlined;
        statusText = '未安�?;
        statusDesc = '请先安装 Shizuku 应用';
        break;
      case ShizukuStatus.unknown:
      default:
        statusColor = AppTheme.textHint;
        statusIcon = Icons.help_outline;
        statusText = '检测中...';
        statusDesc = '正在检�?Shizuku 状�?;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 状态头�?
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLG),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 48),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDesc,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 版本信息
          if (_version != null)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shizuku 版本',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    _version!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (_status) {
      case ShizukuStatus.authorized:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('已配置完�?),
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
          ),
        );
      case ShizukuStatus.notAuthorized:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.vpn_key),
            label: const Text('请求授权'),
            onPressed: _requestPermission,
          ),
        );
      case ShizukuStatus.notStarted:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('按照下方步骤启动 Shizuku'),
            onPressed: null,
          ),
        );
      case ShizukuStatus.notInstalled:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('下载 Shizuku'),
                onPressed: _downloadShizuku,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // 打开Google Play
              },
              child: const Text('或从 Google Play 安装'),
            ),
          ],
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _isChecking 
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
            label: const Text('检测状�?),
            onPressed: _isChecking ? null : _checkStatus,
          ),
        );
    }
  }

  Widget _buildSetupSteps() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                const Text(
                  '设置步骤',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          _buildStepItem(
            number: 1,
            title: '安装 Shizuku',
            description: '�?GitHub �?Google Play 下载安装 Shizuku 应用',
            completed: _status != ShizukuStatus.notInstalled,
          ),
          
          _buildStepItem(
            number: 2,
            title: '启动 Shizuku 服务',
            description: '使用以下任一方式启动：\n�?无线调试：在 Shizuku 中按提示操作\n�?ADB：adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh',
            completed: _status == ShizukuStatus.authorized || 
                       _status == ShizukuStatus.notAuthorized,
            hasCommand: true,
            command: 'adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh',
          ),
          
          _buildStepItem(
            number: 3,
            title: '授权本应�?,
            description: '�?Shizuku 应用中找到本应用并授�?,
            completed: _status == ShizukuStatus.authorized,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int number,
    required String title,
    required String description,
    required bool completed,
    bool hasCommand = false,
    String? command,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤编号
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: completed ? AppTheme.success : AppTheme.warmBeige,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: completed ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: completed 
                      ? AppTheme.textSecondary 
                      : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (hasCommand && command != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            command,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => _copyCommand(command),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Icon(Icons.help_outline, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                const Text(
                  '常见问题',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          _buildFAQItem(
            question: '什么是 Shizuku�?,
            answer: 'Shizuku 是一个让普通应用可以直接使用系�?API 的工具。相�?ADB 方案，它可以完全在手机上运行，无需电脑�?,
          ),
          
          _buildFAQItem(
            question: '每次重启都需要重新配置吗�?,
            answer: '是的，通过无线调试启动�?Shizuku 会在手机重启后失效。如果你的手机已�?Root，可以选择 Root 方式启动实现开机自启�?,
          ),
          
          _buildFAQItem(
            question: '为什么需要这个权限？',
            answer: 'AutoGLM 需要模拟触摸和输入来自动完成任务，这些操作需�?Shizuku 提供的系统权限。所有操作都在您的设备上本地执行�?,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontSize: 14),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Text(
            answer,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _requestPermission() {
    // 调用原生层请求Shizuku权限
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在 Shizuku 应用中授�?)),
    );
  }

  void _downloadShizuku() {
    // 打开Shizuku下载页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请访�?https://shizuku.rikka.app/ 下载')),
    );
  }

  void _copyCommand(String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('命令已复制到剪贴�?)),
    );
  }
}
