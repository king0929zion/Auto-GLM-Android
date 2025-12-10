/// Shizuku服务接口定义
/// 这个抽象类定义了所有需要通过Shizuku实现的设备控制功能
/// 实际实现需要在Android原生层通过Kotlin处理
abstract class ShizukuService {
  /// 检查Shizuku是否可用
  Future<bool> isAvailable();
  
  /// 检查Shizuku权限
  Future<bool> checkPermission();
  
  /// 请求Shizuku权限
  Future<bool> requestPermission();
  
  /// 绑定Shizuku服务
  Future<bool> bindService();
  
  /// 解绑Shizuku服务
  Future<void> unbindService();
  
  /// 获取服务版本
  Future<int> getVersion();
}

/// Shizuku状态
enum ShizukuStatus {
  /// 未安装
  notInstalled,
  
  /// 已安装但未启动
  notStarted,
  
  /// 已启动但未授权
  notAuthorized,
  
  /// 已授权可用
  authorized,
  
  /// 未知状态
  unknown,
}

/// Shizuku服务异常
class ShizukuException implements Exception {
  final String message;
  final ShizukuStatus status;
  
  const ShizukuException(this.message, {this.status = ShizukuStatus.unknown});
  
  @override
  String toString() => 'ShizukuException: $message (status: $status)';
}
