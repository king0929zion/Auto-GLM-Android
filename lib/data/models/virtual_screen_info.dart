/// 虚拟屏幕信息
class VirtualScreenInfo {
  /// 虚拟屏幕的 Display ID
  final int displayId;
  
  /// 屏幕宽度
  final int width;
  
  /// 屏幕高度
  final int height;
  
  /// 屏幕密度 (dpi)
  final int density;
  
  const VirtualScreenInfo({
    required this.displayId,
    required this.width,
    required this.height,
    required this.density,
  });
  
  /// 屏幕宽高比
  double get aspectRatio => width / height;
  
  /// 是否为有效的虚拟屏幕
  bool get isValid => displayId > 0 && width > 0 && height > 0;
  
  @override
  String toString() => 'VirtualScreenInfo(id: $displayId, ${width}x$height, $density dpi)';
}
