/// Shizuku服务接口定义
/// 这个抽象类定义了所有需要通过Shizuku实现的设备控制功�?
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

/// Shizuku状�?
enum ShizukuStatus {
  /// 未安�?
  notInstalled,
  
  /// 已安装但未启�?
  notStarted,
  
  /// 已启动但未授�?
  notAuthorized,
  
  /// 已授权可�?
  authorized,
  
  /// 未知状�?
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
