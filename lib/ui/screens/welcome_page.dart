import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../config/settings_repository.dart';

/// 欢迎/引导页面
/// 首次运行时显示，引导用户完成初始配置
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<_WelcomePageData> _pages = [
    _WelcomePageData(
      icon: Icons.smart_toy,
      title: '欢迎使用 AutoGLM',
      description: 'AI驱动的手机自动化助手，让您用自然语言控制手机�?,
      color: AppTheme.accentOrange,
    ),
    _WelcomePageData(
      icon: Icons.text_fields,
      title: '自然语言操作',
      description: '只需描述您想要完成的任务，AI会自动分析屏幕内容并执行相应操作�?,
      color: AppTheme.accentOrangeDeep,
    ),
    _WelcomePageData(
      icon: Icons.security,
      title: '需�?Shizuku',
      description: '本应用需�?Shizuku 来模拟触摸和输入操作。请确保已安装并授权 Shizuku�?,
      color: AppTheme.info,
    ),
    _WelcomePageData(
      icon: Icons.cloud,
      title: '配置 AI 模型',
      description: '您需要配置一个支持视觉理解的AI模型API，如 AutoGLM 模型服务�?,
      color: AppTheme.success,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text('跳过'),
              ),
            ),
            
            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // 页面指示�?
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.accentOrange
                          : AppTheme.warmBeige,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _currentPage < _pages.length - 1
                      ? _nextPage
                      : _complete,
                  child: Text(
                    _currentPage < _pages.length - 1 ? '下一�? : '开始使�?,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_WelcomePageData page) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // 标题
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // 描述
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    _complete();
  }

  void _complete() async {
    await SettingsRepository.instance.setFirstRunCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}

class _WelcomePageData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _WelcomePageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
