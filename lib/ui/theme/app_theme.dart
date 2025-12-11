import 'package:flutter/material.dart';

/// AutoGLM Mobile 应用主题配置
/// 色彩体系：温暖的米色系
class AppTheme {
  // 主色调 - 温暖的米色系
  static const Color primaryBeige = Color(0xFFF5F1E8);
  static const Color secondaryBeige = Color(0xFFE8DFC3);
  static const Color warmBeige = Color(0xFFDDD4BB);
  
  // 强调色 - 柔和的橙色系  
  static const Color accentOrange = Color(0xFFFFA574);
  static const Color accentOrangeDeep = Color(0xFFFF8C42);
  static const Color accentOrangeLight = Color(0xFFFFD4B8);
  
  // 别名（兼容性）
  static const Color primaryColor = accentOrange;
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  
  // 背景色
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundGrey = Color(0xFFF0F0F0);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  // 文字色
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  
  // 状态色
  static const Color success = Color(0xFF7CB342);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF90A4AE);
  
  // 间距
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  
  // 圆角
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  
  // 按钮高度
  static const double buttonHeight = 48.0;
  static const double buttonMinTouchTarget = 44.0;
  
  /// 创建亮色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: accentOrange,
      scaffoldBackgroundColor: backgroundLight,
      
      // 色彩方案
      colorScheme: const ColorScheme.light(
        primary: accentOrange,
        onPrimary: Colors.white,
        secondary: secondaryBeige,
        onSecondary: textPrimary,
        surface: surfaceWhite,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
        outline: warmBeige,
      ),
      
      // AppBar 主题
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBeige,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // 卡片主题
      cardTheme: CardTheme(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: textHint.withOpacity(0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingSM,
        ),
      ),
      
      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentOrange,
          side: const BorderSide(color: accentOrange, width: 1.5),
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentOrange,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        hintStyle: const TextStyle(color: textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: warmBeige),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: warmBeige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: accentOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: error),
        ),
      ),
      
      // 文字主题
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
      
      // 底部导航主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: accentOrange,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentOrange,
        linearTrackColor: secondaryBeige,
      ),
      
      // 浮动按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentOrange,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // 分割线主题
      dividerTheme: const DividerThemeData(
        color: warmBeige,
        thickness: 1,
        space: spacingMD,
      ),
      
      // 芯片主题
      chipTheme: ChipThemeData(
        backgroundColor: secondaryBeige,
        selectedColor: accentOrange,
        labelStyle: const TextStyle(color: textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingSM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
      ),
      
      // 对话框主题
      dialogTheme: const DialogTheme(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLG)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      
      // 底部弹窗主题
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXL),
          ),
        ),
      ),
      
      // Snackbar主题
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// 创建渐变背景装饰
  static BoxDecoration get gradientBackground {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryBeige, backgroundLight],
      ),
    );
  }
  
  /// 创建卡片阴影
  static List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: textHint.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
  
  /// 创建软阴影
  static List<BoxShadow> get softShadow {
    return [
      BoxShadow(
        color: textHint.withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
