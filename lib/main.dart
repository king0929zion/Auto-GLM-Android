import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/settings_repository.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/screens.dart';
import 'ui/screens/permission_setup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化设置存储
  await SettingsRepository.instance.init();
  
  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.surfaceWhite,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  
  // 锁定竖屏
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const AutoGLMApp());
}

/// AutoGLM Mobile 应用入口
class AutoGLMApp extends StatelessWidget {
  const AutoGLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isFirstRun = SettingsRepository.instance.isFirstRun;
    
    return MaterialApp(
      title: 'AutoGLM Mobile',
      debugShowCheckedModeBanner: false,
      
      // 应用主题
      theme: AppTheme.lightTheme,
      
      // 初始路由 - 首次运行显示欢迎页（包含权限配置），否则直接进入主页
      initialRoute: isFirstRun ? '/welcome' : '/',
      
      // 路由配置
      routes: {
        '/': (context) => const HomePage(),
        '/welcome': (context) => const WelcomePage(),
        '/permission_setup': (context) => const PermissionSetupPage(),
        '/settings': (context) => const SettingsPage(),
        '/apps': (context) => const AppsListPage(),
        '/shizuku': (context) => const ShizukuSetupPage(),
        '/history': (context) => const TaskHistoryPage(),
      },
      
      // 自定义路由（带参数）
      onGenerateRoute: (settings) {
        if (settings.name == '/history') {
          final onTaskSelected = settings.arguments as void Function(String)?;
          return MaterialPageRoute(
            builder: (context) => TaskHistoryPage(
              onTaskSelected: onTaskSelected,
            ),
          );
        }
        return null;
      },
    );
  }
}
