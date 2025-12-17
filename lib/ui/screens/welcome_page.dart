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
      description: 'AI驱动的手机自动化助手\n让您用自然语言控制手机',
      color: AppTheme.accentOrange,
    ),
    _WelcomePageData(
      icon: Icons.auto_awesome,
      title: '智能理解，自动执行',
      description: '只需描述您想要完成的任务\nAI会自动分析屏幕并执行操作',
      color: AppTheme.accentOrangeDeep,
    ),
    _WelcomePageData(
      icon: Icons.accessibility_new,
      title: '简单易用',
      description: '仅需开启无障碍服务和悬浮窗权限\n无需Root，无需复杂配置',
      color: AppTheme.info,
    ),
    _WelcomePageData(
      icon: Icons.cloud,
      title: '配置 AI 模型',
      description: '支持 OpenAI 兼容的 API\n推荐使用魔搭社区的 AutoGLM 模型',
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
            
            // 页面指示器
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
                    _currentPage < _pages.length - 1 ? '下一步' : '开始使用',
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
