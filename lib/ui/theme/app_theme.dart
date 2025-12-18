import 'package:flutter/material.dart';

/// AutoGLM Mobile 应用主题配置
/// 色彩体系：温暖的米色系
class AppTheme {
  // === 新版极简黑白设计体系 ===
  
  // 核心色调
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryDark = Color(0xFF1C1C1E); // Apple style dark
  static const Color scaffoldWhite = Color(0xFFFFFFFF);
  static const Color scaffoldBackgroundColor = scaffoldWhite;
  static const Color surfaceGrey = Color(0xFFF5F5F7); // 极其淡的灰，用于区分层级
  
  // 灰色阶 (Grayscale)
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF2F2F7);
  static const Color grey200 = Color(0xFFE5E5EA); // 边框、分割线
  static const Color grey300 = Color(0xFFD1D1D6);
  static const Color grey400 = Color(0xFFC7C7CC); // 占位符
  static const Color grey600 = Color(0xFF8E8E93); // 次要文字
  static const Color grey800 = Color(0xFF3C3C43); // 主要文字
  
  // 功能色
  static const Color functionalError = Color(0xFFE02020); // 更有质感的红
  static const Color functionalSuccess = Color(0xFF34C759); // 清新的绿
  static const Color functionalWarning = Color(0xFFFF9500);
  
  // === 兼容旧版变量名 (映射到新版极简色系) ===
  
  // 原主色调 (米色) -> 映射为白色/浅灰
  static const Color primaryBeige = scaffoldWhite;
  static const Color secondaryBeige = grey100;
  static const Color warmBeige = grey200; // 常用作边框
  
  // 原强调色 (橙色) -> 映射为黑色 (作为主要行动点)
  static const Color accentOrange = primaryBlack;
  static const Color accentOrangeDeep = primaryDark;
  static const Color accentOrangeLight = grey200; // 原淡橙色背景 -> 淡灰
  
  // 别名
  static const Color primaryColor = primaryBlack;
  static const Color backgroundColor = grey50; // 深色模式背景 (保留定义但暂不强调)
  static const Color surfaceColor = primaryDark; // 深色模式表面 (保留定义)
  
  // 背景色
  static const Color backgroundLight = scaffoldWhite;
  static const Color backgroundGrey = grey50;
  static const Color surfaceWhite = scaffoldWhite;
  
  // 文字色
  static const Color textPrimary = primaryBlack;
  static const Color textSecondary = grey600; // 更加精致的灰
  static const Color textHint = grey400;
  
  // 状态色
  static const Color success = functionalSuccess;
  static const Color error = functionalError;
  static const Color warning = functionalWarning;
  static const Color info = grey600;
  
  // 间距 - 保持不变
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  
  // 圆角 - 稍微减小圆角，显得更干练
  static const double radiusSM = 4.0;
  static const double radiusMD = 8.0;
  static const double radiusLG = 12.0;
  static const double radiusXL = 16.0;
  
  // 按钮高度
  static const double buttonHeight = 48.0;
  static const double buttonMinTouchTarget = 44.0;
  
  /// 创建极简亮色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlack,
      scaffoldBackgroundColor: scaffoldWhite,
      
      // 色彩方案
      colorScheme: const ColorScheme.light(
        primary: primaryBlack,
        onPrimary: Colors.white,
        secondary: grey800,
        onSecondary: Colors.white,
        surface: scaffoldWhite,
        onSurface: primaryBlack,
        error: functionalError,
        onError: Colors.white,
        outline: grey200,
      ),
      
      // AppBar 主题 - 极简白底黑字
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldWhite,
        foregroundColor: primaryBlack,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0, // 滚动时不显示阴影
        titleTextStyle: TextStyle(
          color: primaryBlack,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5, // 稍微紧凑的字间距
        ),
        iconTheme: IconThemeData(color: primaryBlack),
      ),
      
      // 卡片主题 - 极简，去阴影，加边框
      cardTheme: CardThemeData(
        color: scaffoldWhite,
        elevation: 0, // 去除阴影，扁平化
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
          side: const BorderSide(color: grey200, width: 1.0), // 细边框
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingSM,
        ),
      ),
      
      // 按钮主题 - 黑底白字
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: Colors.white,
          elevation: 0, // 扁平化
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlack,
          side: const BorderSide(color: primaryBlack, width: 1.5),
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
          foregroundColor: primaryBlack,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey50,
        hintStyle: const TextStyle(color: textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryBlack, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: error),
        ),
      ),
      
      // 文字主题 - 使用更现代的字重
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryBlack,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryBlack,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryBlack,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryBlack,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryBlack,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryBlack,
        ),
      ),
      
      // 底部导航主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: scaffoldWhite,
        selectedItemColor: primaryBlack,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),
      
      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlack,
        linearTrackColor: grey200,
      ),
      
      // 浮动按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // 分割线主题
      dividerTheme: const DividerThemeData(
        color: grey200,
        thickness: 1,
        space: spacingMD,
      ),
      
      // 芯片主题
      chipTheme: ChipThemeData(
        backgroundColor: grey100,
        selectedColor: primaryBlack,
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        secondarySelectedColor: primaryBlack,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingSM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      
      // 对话框主题
      dialogTheme: const DialogThemeData(
        backgroundColor: scaffoldWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLG)),
          side: BorderSide(color: grey200), // 细边框代替阴影
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryBlack,
        ),
      ),
      
      // 底部弹窗主题
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: scaffoldWhite,
        modalBackgroundColor: scaffoldWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXL),
          ),
          side: BorderSide(color: grey200), // 顶部边框
        ),
      ),
      
      // Snackbar主题
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryBlack,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      iconTheme: const IconThemeData(
        color: primaryBlack,
        size: 24,
      ),
    );
  }
  
  /// 创建渐变背景装饰 - 极简风格不需要渐变，返回纯色
  static BoxDecoration get gradientBackground {
    return const BoxDecoration(
      color: scaffoldWhite,
    );
  }
  
  /// 创建卡片阴影 - 极简风格去阴影，返回空列表
  static List<BoxShadow> get cardShadow {
    return [];
  }
  
  /// 创建软阴影 - 极简风格去阴影，只保留极淡的轮廓
  static List<BoxShadow> get softShadow {
    return [
      BoxShadow(
        color: primaryBlack.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
