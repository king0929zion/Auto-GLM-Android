import 'package:flutter/material.dart';

/// 触控点可视化组件 - 显示AI操作的位置和轨迹
class TouchVisualizer extends StatefulWidget {
  /// 操作类型: tap, doubleTap, longPress, swipe
  final String actionType;
  
  /// 触控位置 (相对坐标 0-1)
  final Offset position;
  
  /// 结束位置 (用于滑动, 相对坐标 0-1)
  final Offset? endPosition;
  
  /// 容器尺寸
  final Size containerSize;
  
  /// 动画完成回调
  final VoidCallback? onComplete;
  
  const TouchVisualizer({
    super.key,
    required this.actionType,
    required this.position,
    this.endPosition,
    required this.containerSize,
    this.onComplete,
  });
  
  @override
  State<TouchVisualizer> createState() => _TouchVisualizerState();
}

class _TouchVisualizerState extends State<TouchVisualizer> 
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _fadeController;
  late Animation<double> _rippleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _rippleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _startAnimation();
  }
  
  void _startAnimation() async {
    await _rippleController.forward();
    await _fadeController.forward();
    widget.onComplete?.call();
  }
  
  @override
  void dispose() {
    _rippleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final absolutePos = Offset(
      widget.position.dx * widget.containerSize.width,
      widget.position.dy * widget.containerSize.height,
    );
    
    return AnimatedBuilder(
      animation: Listenable.merge([_rippleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: widget.containerSize,
          painter: _TouchPainter(
            actionType: widget.actionType,
            position: absolutePos,
            endPosition: widget.endPosition != null
                ? Offset(
                    widget.endPosition!.dx * widget.containerSize.width,
                    widget.endPosition!.dy * widget.containerSize.height,
                  )
                : null,
            rippleProgress: _rippleAnimation.value,
            opacity: _fadeAnimation.value,
          ),
        );
      },
    );
  }
}

/// 触控点绘制器
class _TouchPainter extends CustomPainter {
  final String actionType;
  final Offset position;
  final Offset? endPosition;
  final double rippleProgress;
  final double opacity;
  
  _TouchPainter({
    required this.actionType,
    required this.position,
    this.endPosition,
    required this.rippleProgress,
    required this.opacity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    switch (actionType) {
      case 'tap':
      case 'Tap':
      case 'click':
        _paintTapRipple(canvas);
        break;
      case 'doubleTap':
      case 'Double Tap':
        _paintDoubleTap(canvas);
        break;
      case 'longPress':
      case 'Long Press':
        _paintLongPress(canvas);
        break;
      case 'swipe':
      case 'Swipe':
      case 'scroll':
        _paintSwipe(canvas);
        break;
      default:
        _paintTapRipple(canvas);
    }
  }
  
  void _paintTapRipple(Canvas canvas) {
    final maxRadius = 50.0;
    final radius = maxRadius * rippleProgress;
    
    // 外圈涟漪
    final ripplePaint = Paint()
      ..color = Colors.white.withOpacity(0.4 * opacity * (1 - rippleProgress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(position, radius, ripplePaint);
    
    // 中心点
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.8 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8 * (1 - rippleProgress * 0.5), centerPaint);
    
    // 第二层涟漪
    if (rippleProgress > 0.3) {
      final secondRipple = Paint()
        ..color = Colors.white.withOpacity(0.2 * opacity * (1 - rippleProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(position, radius * 0.6, secondRipple);
    }
  }
  
  void _paintDoubleTap(Canvas canvas) {
    final maxRadius = 40.0;
    
    // 两个同心涟漪
    for (int i = 0; i < 2; i++) {
      final delay = i * 0.3;
      final progress = (rippleProgress - delay).clamp(0.0, 1.0);
      if (progress > 0) {
        final radius = maxRadius * progress;
        final ripplePaint = Paint()
          ..color = Colors.cyan.withOpacity(0.5 * opacity * (1 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(position, radius, ripplePaint);
      }
    }
    
    // 中心双圈
    final centerPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(position, 10, centerPaint);
    canvas.drawCircle(position, 5, Paint()..color = Colors.cyan.withOpacity(0.9 * opacity));
  }
  
  void _paintLongPress(Canvas canvas) {
    final maxRadius = 60.0;
    final radius = maxRadius * rippleProgress;
    
    // 脉冲圆
    final pulsePaint = Paint()
      ..color = Colors.orange.withOpacity(0.3 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius, pulsePaint);
    
    // 外圈
    final ringPaint = Paint()
      ..color = Colors.orange.withOpacity(0.7 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(position, radius, ringPaint);
    
    // 中心
    final centerPaint = Paint()
      ..color = Colors.orange.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 10, centerPaint);
  }
  
  void _paintSwipe(Canvas canvas) {
    if (endPosition == null) return;
    
    final start = position;
    final end = endPosition!;
    
    // 轨迹线
    final pathPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    // 绘制渐变轨迹
    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(
      start.dx + (end.dx - start.dx) * rippleProgress,
      start.dy + (end.dy - start.dy) * rippleProgress,
    );
    canvas.drawPath(path, pathPaint);
    
    // 起点
    final startPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.5 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 8, startPaint);
    
    // 当前位置（移动中的点）
    final currentPos = Offset(
      start.dx + (end.dx - start.dx) * rippleProgress,
      start.dy + (end.dy - start.dy) * rippleProgress,
    );
    final currentPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentPos, 10, currentPaint);
    
    // 箭头指示方向
    if (rippleProgress > 0.5) {
      _drawArrow(canvas, currentPos, end, Colors.greenAccent.withOpacity(0.8 * opacity));
    }
  }
  
  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final direction = (to - from);
    if (direction.distance < 20) return;
    
    final normalized = direction / direction.distance;
    final arrowSize = 15.0;
    
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final arrowPath = Path();
    final tip = from + normalized * 20;
    final left = tip - normalized * arrowSize + Offset(-normalized.dy, normalized.dx) * arrowSize * 0.5;
    final right = tip - normalized * arrowSize + Offset(normalized.dy, -normalized.dx) * arrowSize * 0.5;
    
    arrowPath.moveTo(left.dx, left.dy);
    arrowPath.lineTo(tip.dx, tip.dy);
    arrowPath.lineTo(right.dx, right.dy);
    
    canvas.drawPath(arrowPath, arrowPaint);
  }
  
  @override
  bool shouldRepaint(covariant _TouchPainter oldDelegate) {
    return rippleProgress != oldDelegate.rippleProgress ||
           opacity != oldDelegate.opacity;
  }
}

/// 触控可视化覆盖层 - 管理多个触控动画
class TouchVisualizerOverlay extends StatefulWidget {
  final Widget child;
  
  const TouchVisualizerOverlay({
    super.key,
    required this.child,
  });
  
  static TouchVisualizerOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<TouchVisualizerOverlayState>();
  }
  
  @override
  State<TouchVisualizerOverlay> createState() => TouchVisualizerOverlayState();
}

class TouchVisualizerOverlayState extends State<TouchVisualizerOverlay> {
  final List<_TouchVisualizerEntry> _entries = [];
  int _idCounter = 0;
  
  /// 显示触控动画
  void showTouch({
    required String actionType,
    required Offset position,
    Offset? endPosition,
  }) {
    final id = _idCounter++;
    setState(() {
      _entries.add(_TouchVisualizerEntry(
        id: id,
        actionType: actionType,
        position: position,
        endPosition: endPosition,
      ));
    });
  }
  
  void _removeEntry(int id) {
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._entries.map((entry) => Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return TouchVisualizer(
                actionType: entry.actionType,
                position: entry.position,
                endPosition: entry.endPosition,
                containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                onComplete: () => _removeEntry(entry.id),
              );
            },
          ),
        )),
      ],
    );
  }
}

class _TouchVisualizerEntry {
  final int id;
  final String actionType;
  final Offset position;
  final Offset? endPosition;
  
  _TouchVisualizerEntry({
    required this.id,
    required this.actionType,
    required this.position,
    this.endPosition,
  });
}
