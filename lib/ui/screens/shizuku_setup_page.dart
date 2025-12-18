import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../services/shizuku/shizuku_service.dart';

/// Shizuku设置和引导页面
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
      // 这里会调用原生层检查Shizuku状态
      // 目前使用模拟数据
      await Future.delayed(const Duration(milliseconds: 500));

      // 实际实现会从Platform Channel获取
      setState(() {
        _status = ShizukuStatus.notAuthorized; // 模拟状态
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
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Shizuku 设置',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isChecking ? null : _checkStatus,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // 状态卡片
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
        statusText = '已就绪';
        statusDesc = 'Shizuku 服务运行正常';
        break;
      case ShizukuStatus.notAuthorized:
        statusColor = AppTheme.warning;
        statusIcon = Icons.warning_amber;
        statusText = '需要授权';
        statusDesc = 'Shizuku 需要本应用授权';
        break;
      case ShizukuStatus.notStarted:
        statusColor = AppTheme.error;
        statusIcon = Icons.error_outline;
        statusText = '未启动';
        statusDesc = '服务未启动';
        break;
      case ShizukuStatus.notInstalled:
        statusColor = AppTheme.textHint;
        statusIcon = Icons.cancel_outlined;
        statusText = '未安装';
        statusDesc = '请先安装 Shizuku';
        break;
      case ShizukuStatus.unknown:
      default:
        statusColor = AppTheme.textHint;
        statusIcon = Icons.help_outline;
        statusText = '检测中...';
        statusDesc = '正在检测状态';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        children: [
          // 状态头部
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 40),
                const SizedBox(width: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shizuku 版本',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    _version!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),

          if (_version != null)
            const Divider(height: 1, color: AppTheme.grey100),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(16),
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
            icon: const Icon(Icons.check, size: 18),
            label: const Text('已配置完成'),
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      case ShizukuStatus.notAuthorized:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.vpn_key, size: 18),
            label: const Text('请求授权'),
            onPressed: _requestPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlack,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      case ShizukuStatus.notStarted:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('查看下方启动步骤'),
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlack,
              side: const BorderSide(color: AppTheme.grey300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      case ShizukuStatus.notInstalled:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('下载 Shizuku'),
                onPressed: _downloadShizuku,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlack,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // 打开Google Play
              },
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              child: const Text('或从 Google Play 安装',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryBlack),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text('检测状态'),
            onPressed: _isChecking ? null : _checkStatus,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlack,
              side: const BorderSide(color: AppTheme.primaryBlack),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
    }
  }

  Widget _buildSetupSteps() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered,
                    color: AppTheme.primaryBlack, size: 20),
                const SizedBox(width: 12),
                const Text(
                  '配置步骤',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.grey100),
          _buildStepItem(
            number: 1,
            title: '安装 Shizuku',
            description: '从 GitHub 或 Google Play 下载安装 Shizuku 应用',
            completed: _status != ShizukuStatus.notInstalled,
          ),
          _buildStepItem(
            number: 2,
            title: '启动 Shizuku 服务',
            description:
                '使用以下任一方式启动：\n• 无线调试：在 Shizuku 中按提示操作\n• ADB：连接电脑执行启动脚本',
            completed: _status == ShizukuStatus.authorized ||
                _status == ShizukuStatus.notAuthorized,
            hasCommand: true,
            command:
                'adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh',
          ),
          _buildStepItem(
            number: 3,
            title: '授权本应用',
            description: '在 Shizuku 应用中找到本应用并授权',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤编号
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: completed ? AppTheme.primaryBlack : AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(
                      '$number',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: completed
                        ? AppTheme.textPrimary
                        : AppTheme.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (hasCommand && command != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.grey50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ADB 命令',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => _copyCommand(command),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  '复制',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryBlack,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          command,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.help_outline,
                    color: AppTheme.primaryBlack, size: 20),
                const SizedBox(width: 12),
                const Text(
                  '常见问题',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.grey100),
          _buildFAQItem(
            question: '什么是 Shizuku？',
            answer:
                'Shizuku 是一个让普通应用可以直接使用系统 API 的工具。相比 ADB 方案，它可以完全在手机上运行，无需电脑。',
          ),
          _buildFAQItem(
            question: '每次重启都需要重新配置吗？',
            answer:
                '是的，通过无线调试启动的 Shizuku 会在手机重启后失效。如果你的手机已经 Root，可以选择 Root 方式启动实现开机自启。',
          ),
          _buildFAQItem(
            question: '为什么需要这个权限？',
            answer:
                'AutoGLM 需要模拟触摸和输入来自动完成任务，这些操作需要 Shizuku 提供的系统权限。所有操作都在您的设备上本地执行。',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryBlack,
          ),
        ),
        iconColor: AppTheme.primaryBlack,
        collapsedIconColor: AppTheme.grey400,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              answer,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _requestPermission() {
    // 调用原生层请求Shizuku权限
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在 Shizuku 应用中授权')),
    );
  }

  void _downloadShizuku() {
    // 打开Shizuku下载页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请访问 https://shizuku.rikka.app/ 下载')),
    );
  }

  void _copyCommand(String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('命令已复制到剪贴板')),
    );
  }
}
