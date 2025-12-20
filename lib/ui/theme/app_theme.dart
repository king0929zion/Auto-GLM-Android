import 'package:flutter/material.dart';

/// AutoZi 极简设计系统
/// 设计理念：Less is More - 纯净、专注、优雅
class AppTheme {
  AppTheme._();

  // ============================================
  // 🎨 色彩系统 - 极简黑白灰
  // ============================================
  
  // 主色调
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  
  // 灰度阶梯 (12级精细灰度)
  static const Color grey50 = Color(0xFFFAFAFA);   // 几乎白色背景
  static const Color grey100 = Color(0xFFF5F5F5);  // 极淡灰背景
  static const Color grey150 = Color(0xFFEEEEEE);  // 分割线
  static const Color grey200 = Color(0xFFE0E0E0);  // 边框
  static const Color grey300 = Color(0xFFBDBDBD);  // 禁用态
  static const Color grey400 = Color(0xFF9E9E9E);  // 占位符
  static const Color grey500 = Color(0xFF757575);  // 次要文字
  static const Color grey600 = Color(0xFF616161);  // 辅助文字
  static const Color grey700 = Color(0xFF424242);  // 正文
  static const Color grey800 = Color(0xFF303030);  // 标题
  static const Color grey900 = Color(0xFF1A1A1A);  // 深黑

  // 功能色 - 极简单色调
  static const Color success = Color(0xFF10B981);  // 翠绿
  static const Color error = Color(0xFFEF4444);    // 红
  static const Color warning = Color(0xFFF59E0B);  // 橙
  static const Color info = Color(0xFF6B7280);     // 灰

  // 语义化别名
  static const Color primaryBlack = black;
  static const Color primaryDark = grey900;
  static const Color scaffoldWhite = white;
  static const Color scaffoldBackgroundColor = white;
  static const Color surfaceWhite = white;
  static const Color surfaceGrey = grey50;

  // 文字色
  static const Color textPrimary = grey900;
  static const Color textSecondary = grey500;
  static const Color textHint = grey400;
  static const Color textDisabled = grey300;

  // 兼容旧代码
  static const Color primaryBeige = white;
  static const Color secondaryBeige = grey100;
  static const Color warmBeige = grey200;
  static const Color accentOrange = black;
  static const Color accentOrangeDeep = grey900;
  static const Color accentOrangeLight = grey100;
  static const Color primaryColor = black;
  static const Color backgroundColor = grey50;
  static const Color surfaceColor = grey900;
  static const Color backgroundLight = white;
  static const Color backgroundGrey = grey50;

  // ============================================
  // 📏 间距系统 - 8px 基准
  // ============================================
  
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // 兼容旧代码
  static const double spacingXS = space4;
  static const double spacingSM = space8;
  static const double spacingMD = space16;
  static const double spacingLG = space24;
  static const double spacingXL = space32;

  // ============================================
  // 🔲 圆角系统 - 更小更精致
  // ============================================
  
  static const double radius0 = 0.0;
  static const double radius4 = 4.0;
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius10 = 10.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radiusFull = 999.0;

  // 兼容旧代码
  static const double radiusSM = radius4;
  static const double radiusMD = radius8;
  static const double radiusLG = radius12;
  static const double radiusXL = radius16;

  // ============================================
  // 📐 尺寸系统
  // ============================================
  
  static const double buttonHeight = 52.0;
  static const double buttonHeightSmall = 40.0;
  static const double inputHeight = 52.0;
  static const double iconSize = 22.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeLarge = 28.0;
  static const double buttonMinTouchTarget = 44.0;

  // ============================================
  // 🔤 字体系统
  // ============================================
  
  static const String fontFamily = 'ResourceHanRounded';
  
  // 字号阶梯
  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize15 = 15.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize28 = 28.0;
  static const double fontSize32 = 32.0;
  static const double fontSize36 = 36.0;

  // ============================================
  // 🎭 动效时长
  // ============================================
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Curve curveDefault = Curves.easeOutCubic;

  // ============================================
  // 🌟 主题配置
  // ============================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      primaryColor: black,
      scaffoldBackgroundColor: white,
      
      // 色彩方案
      colorScheme: const ColorScheme.light(
        primary: black,
        onPrimary: white,
        secondary: grey700,
        onSecondary: white,
        surface: white,
        onSurface: grey900,
        error: error,
        onError: white,
        outline: grey200,
      ),
      
      // AppBar - 完全透明融入背景
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: grey900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: grey900,
          fontSize: fontSize18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: grey900, size: iconSize),
      ),
      
      // 卡片 - 极简无阴影
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius12),
          side: const BorderSide(color: grey150, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // 按钮 - 黑白分明
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: grey900,
          side: const BorderSide(color: grey200, width: 1.5),
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: grey700,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // 输入框 - 极简线条
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey50,
        hintStyle: const TextStyle(
          color: grey400,
          fontSize: fontSize15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: grey900, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
      ),
      
      // 文字样式
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontSize: fontSize36,
          fontWeight: FontWeight.w700,
          color: grey900,
          letterSpacing: -1.5,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: fontSize32,
          fontWeight: FontWeight.w700,
          color: grey900,
          letterSpacing: -1.0,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: fontSize28,
          fontWeight: FontWeight.w600,
          color: grey900,
          letterSpacing: -0.5,
          height: 1.3,
        ),
        // Headline
        headlineLarge: TextStyle(
          fontSize: fontSize24,
          fontWeight: FontWeight.w600,
          color: grey900,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: fontSize20,
          fontWeight: FontWeight.w600,
          color: grey900,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: fontSize18,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
        // Title
        titleLarge: TextStyle(
          fontSize: fontSize16,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
        titleMedium: TextStyle(
          fontSize: fontSize15,
          fontWeight: FontWeight.w500,
          color: grey900,
        ),
        titleSmall: TextStyle(
          fontSize: fontSize14,
          fontWeight: FontWeight.w500,
          color: grey600,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: fontSize16,
          fontWeight: FontWeight.w400,
          color: grey800,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: fontSize14,
          fontWeight: FontWeight.w400,
          color: grey700,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: fontSize12,
          fontWeight: FontWeight.w400,
          color: grey500,
          height: 1.5,
        ),
        // Label
        labelLarge: TextStyle(
          fontSize: fontSize14,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
        labelMedium: TextStyle(
          fontSize: fontSize12,
          fontWeight: FontWeight.w500,
          color: grey600,
        ),
        labelSmall: TextStyle(
          fontSize: fontSize10,
          fontWeight: FontWeight.w500,
          color: grey500,
          letterSpacing: 0.5,
        ),
      ),
      
      // 分割线
      dividerTheme: const DividerThemeData(
        color: grey150,
        thickness: 1,
        space: 0,
      ),
      
      // 进度指示器
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: black,
        linearTrackColor: grey150,
      ),
      
      // 底部弹窗
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        modalBackgroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius20)),
        ),
      ),
      
      // 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius16),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize18,
          fontWeight: FontWeight.w600,
          color: grey900,
        ),
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: grey900,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: white,
          fontSize: fontSize14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // 图标
      iconTheme: const IconThemeData(
        color: grey900,
        size: iconSize,
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: grey100,
        selectedColor: black,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: grey700,
          fontSize: fontSize13,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: space12, vertical: space6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius6),
        ),
      ),
      
      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: space16, vertical: space4),
        minLeadingWidth: 0,
        horizontalTitleGap: space12,
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          return grey400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return black;
          return grey200;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  // ============================================
  // 🛠️ 工具方法
  // ============================================

  /// 无阴影
  static List<BoxShadow> get noShadow => [];

  /// 极淡阴影
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// 柔和阴影
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// 悬浮阴影
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: black.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // 兼容旧代码
  static List<BoxShadow> get cardShadow => noShadow;
  static BoxDecoration get gradientBackground => const BoxDecoration(color: white);
}
