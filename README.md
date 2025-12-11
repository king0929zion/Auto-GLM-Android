# AutoGLM Mobile (Auto-GLM-Android)

基于 Open-AutoGLM 的移动端智能自动化助手，使用 Flutter + Shizuku 实现完全移动端的手机自动控制。

## 🎯 项目概述

将 Python 版 AutoGLM 手机自动化框架完整移植为原生移动端应用：
- **保持AI接口兼容**：继续使用OpenAI兼容API，无需修改模型服务端
- **替换设备控制层**：使用Shizuku替代ADB，实现移动端原生设备控制
- **100%复用业务逻辑**：完全复刻原有的Agent逻辑、动作处理和系统提示词

## 📊 功能复刻对照表

| 原Python模块 | Flutter实现 | 复刻程度 |
|-------------|------------|---------|
| `phone_agent/agent.py` | `lib/core/phone_agent.dart` | ✅ 100% |
| `phone_agent/model/client.py` | `lib/services/model/model_client.dart` | ✅ 100% |
| `phone_agent/actions/handler.py` | `lib/services/device/action_handler.dart` | ✅ 100% |
| `phone_agent/config/prompts_zh.py` | `lib/config/prompts_zh.dart` | ✅ 100% |
| `phone_agent/config/prompts_en.py` | `lib/config/prompts_en.dart` | ✅ 100% |
| `phone_agent/config/apps.py` | `lib/config/apps.dart` | ✅ 100% |
| `phone_agent/config/i18n.py` | `lib/config/i18n.dart` | ✅ 100% |
| `main.py` (CLI入口) | `lib/main.dart` + UI Pages | ✅ 适配为移动UI |
| `main.py` (check_system_requirements) | `lib/core/system_checker.dart` | ✅ 100% |
| `main.py` (check_model_api) | `lib/core/system_checker.dart` | ✅ 100% |
| `main.py` (--list-apps) | `lib/ui/screens/apps_list_page.dart` | ✅ 100% |
| `phone_agent/adb/device.py` | `lib/services/device/device_controller.dart` | ✅ Shizuku替代 |
| `phone_agent/adb/screenshot.py` | Android原生层 | ✅ MediaProjection替代 |
| `phone_agent/adb/input.py` | Android原生层 | ✅ InputManager替代 |
| `phone_agent/adb/connection.py` | 不需要 | ➖ 移动端无此需求 |

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────┐
│                    Flutter UI层                      │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │  HomePage   │ │ SettingsPage │ │  AppsListPage│  │
│  │  WelcomePage│ │ ShizukuSetup │ │TaskHistoryPg │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
├─────────────────────────────────────────────────────┤
│                    业务逻辑层                        │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ PhoneAgent  │ │ ActionHandler│ │ ModelClient  │  │
│  │SystemChecker│ │ActionParser  │ │MessageBuilder│  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
├─────────────────────────────────────────────────────┤
│                    配置与数据层                      │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │PromptZh/En │ │ AppPackages  │ │SettingsRepo  │  │
│  │   I18n     │ │ TaskInfo     │ │ ActionData   │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
├─────────────────────────────────────────────────────┤
│              Android原生层 (Kotlin)                  │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │MainActivity │ │DeviceControl │ │  Shizuku     │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 📁 项目结构

```
Auto-GLM-Android/
├── lib/                                    # Flutter Dart代码
│   ├── main.dart                          # 应用入口
│   │
│   ├── config/                            # 配置文件 (7个文件)
│   │   ├── app_config.dart                # 应用常量配置
│   │   ├── apps.dart                      # 100+应用包名映射
│   │   ├── prompts_zh.dart                # 中文系统提示词 (复刻)
│   │   ├── prompts_en.dart                # 英文系统提示词 (复刻)
│   │   ├── i18n.dart                      # 国际化支持 (复刻)
│   │   ├── settings_repository.dart       # 设置持久化
│   │   └── config.dart                    # 导出文件
│   │
│   ├── core/                              # 核心逻辑 (4个文件)
│   │   ├── phone_agent.dart               # PhoneAgent主类 (复刻agent.py)
│   │   ├── action_parser.dart             # 健壮的动作解析器
│   │   ├── system_checker.dart            # 系统检查 (复刻main.py)
│   │   └── core.dart                      # 导出文件
│   │
│   ├── data/models/                       # 数据模型 (5个文件)
│   │   ├── action_data.dart               # 动作数据 (含parse_action)
│   │   ├── model_config.dart              # 模型配置
│   │   ├── screenshot_data.dart           # 截图数据
│   │   ├── task_info.dart                 # 任务和步骤结果
│   │   └── models.dart                    # 导出文件
│   │
│   ├── services/                          # 服务层
│   │   ├── device/                        # 设备控制 (3个文件)
│   │   │   ├── device_controller.dart     # 设备控制器 (替代adb/)
│   │   │   ├── action_handler.dart        # 动作处理器 (复刻handler.py)
│   │   │   └── device.dart                # 导出文件
│   │   ├── model/                         # 模型服务 (2个文件)
│   │   │   ├── model_client.dart          # 模型客户端 (复刻client.py)
│   │   │   └── model.dart                 # 导出文件
│   │   └── shizuku/                       # Shizuku服务 (1个文件)
│   │       └── shizuku_service.dart       # Shizuku接口定义
│   │
│   └── ui/                                # UI组件
│       ├── theme/                         # 主题 (1个文件)
│       │   └── app_theme.dart             # 米色系主题配置
│       ├── widgets/                       # 通用组件 (5个文件)
│       │   ├── screenshot_preview.dart    # 截图预览
│       │   ├── task_input_field.dart      # 任务输入框
│       │   ├── thinking_card.dart         # 思考过程卡片
│       │   ├── task_status_bar.dart       # 任务状态栏
│       │   └── widgets.dart               # 导出文件
│       └── screens/                       # 页面 (7个文件)
│           ├── home_page.dart             # 主页面
│           ├── settings_page.dart         # 设置页面
│           ├── apps_list_page.dart        # 应用列表 (复刻--list-apps)
│           ├── shizuku_setup_page.dart    # Shizuku设置引导
│           ├── task_history_page.dart     # 任务历史
│           ├── welcome_page.dart          # 欢迎引导页
│           └── screens.dart               # 导出文件
│
├── android/                               # Android原生代码
│   └── app/src/main/
│       ├── kotlin/.../
│       │   ├── MainActivity.kt            # Flutter桥接
│       │   └── DeviceController.kt        # Shizuku设备控制
│       └── AndroidManifest.xml            # 权限配置
│
└── pubspec.yaml                           # Flutter依赖配置
```

## 📈 项目统计

| 类别 | 数量 |
|-----|------|
| Dart 文件 | 28 个 |
| Kotlin 文件 | 2 个 |
| 总代码行数 | ~4500 行 |
| 支持的应用 | 100+ 个 |
| 支持的动作类型 | 14 种 |
| 支持的语言 | 2 种 (中文/英文) |

## 🎨 UI设计规范

严格遵循用户要求的视觉规范：

### 色彩体系
- **主色调**：温暖的米色系 `#F5F1E8`, `#E8DFC3`
- **强调色**：柔和的橙色系 `#FFA574`, `#FF8C42`
- **背景色**：浅灰白色 `#FAFAFA`, `#F0F0F0`
- **文字色**：深灰色 `#333333`, `#666666`
- **禁止使用**：蓝紫色系、渐变色、高饱和度颜色

### 布局原则
- 卡片式布局，圆角半径 12-16dp
- 操作按钮高度 48dp，最小点击区域 44dp
- 截图预览最大占用 60% 屏幕高度
- 进度指示器位于屏幕底部 1/3 处

## 🔧 支持的动作类型（14种）

完整复刻原项目所有动作：

| 动作名称 | 功能描述 |
|---------|---------|
| `Launch` | 启动指定应用 |
| `Tap` | 点击指定坐标 |
| `Type` / `Type_Name` | 输入文本 |
| `Swipe` | 滑动手势 |
| `Back` | 返回键 |
| `Home` | 主页键 |
| `Double Tap` | 双击 |
| `Long Press` | 长按 |
| `Wait` | 等待 |
| `Take_over` | 用户接管 |
| `Note` | 记录内容 |
| `Call_API` | API调用 |
| `Interact` | 交互请求 |
| `finish` | 结束任务 |

## 🚀 快速开始

### 1. 环境要求
- Android 9.0+ (API 28+)
- Shizuku 13.0+
- Flutter 3.10+

### 2. 安装依赖
```bash
cd Auto-GLM-Android
flutter pub get
```

### 3. 安装并配置Shizuku
```bash
# 通过ADB启动Shizuku服务
adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh
```

### 4. 配置模型API
在应用设置中配置：
- API URL: `https://api-inference.modelscope.cn/v1`（魔搭社区推理API）
- API Key: 在[魔搭社区](https://www.modelscope.cn)获取你的API Token
- 模型名称: `ZhipuAI/AutoGLM-Phone-9B`

> ⚠️ **重要**：必须在魔搭社区获取有效的API Token，否则会报错。默认配置不含 API Key，需要用户自行填写。

### 5. 运行
```bash
flutter run
```

## 📝 API兼容性

本项目与原 Python 版 Open-AutoGLM 完全兼容：
- ✅ OpenAI兼容API格式
- ✅ 相同的系统提示词
- ✅ 相同的动作指令格式 (`do()`, `finish()`)
- ✅ 相同的坐标系统（0-999相对坐标）
- ✅ 相同的响应解析格式（`<think>...</think><answer>...</answer>`）

## 📄 页面说明

| 页面 | 功能 |
|-----|------|
| **WelcomePage** | 首次运行引导页 |
| **HomePage** | 主任务执行界面 |
| **SettingsPage** | 模型配置、Agent配置、Shizuku状态 |
| **AppsListPage** | 查看100+支持的应用（分类筛选） |
| **TaskHistoryPage** | 任务历史记录和复用 |
| **ShizukuSetupPage** | Shizuku安装和配置引导 |

## 📄 许可证

继承原 Open-AutoGLM 项目许可证。
