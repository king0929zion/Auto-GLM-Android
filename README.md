# AutoGLM Mobile (Auto-GLM-Android)

基于 Open-AutoGLM 的移动端智能自动化助手，采用 **无障碍服务 + Shizuku** 双权限方案，实现完全移动端的手机自动控制。

## 🎯 项目概述

将 Python 版 AutoGLM 手机自动化框架完整移植为原生移动端应用：
- **保持AI接口兼容**：继续使用OpenAI兼容API，无需修改模型服务端
- **双权限互补方案**：无障碍服务为主力，Shizuku提供增强功能和低版本兼容
- **100%复用业务逻辑**：完全复刻原有的Agent逻辑、动作处理和系统提示词

## 🔐 权限方案说明

### 为什么需要双权限？

本项目采用 **无障碍服务（主） + Shizuku（辅）** 的双权限互补方案：

| 权限方案 | 用途 | 优势 | 限制 |
|---------|------|------|------|
| **无障碍服务** | 主力方案 | ✅ 一次授权永久有效<br>✅ 完美支持中文输入<br>✅ 截图速度快（50-100ms）<br>✅ 无需重启后重新激活 | ❌ 截图需要 Android 11+ |
| **Shizuku** | 增强 & 降级方案 | ✅ 支持 Android 9+<br>✅ 提供更底层的系统控制<br>✅ 任意坐标精确触摸 | ❌ 重启后需重新激活<br>❌ 中文输入需安装 ADB Keyboard |

**功能降级策略**：
- **截图**：无障碍服务（Android 11+）→ Shizuku screencap（Android 9+）
- **文本输入**：无障碍 ACTION_SET_TEXT → Shizuku + ADB Keyboard → input text
- **触摸操作**：Shizuku InputManager 注入事件 → Shell 命令降级

**推荐配置**：
- ✅ **Android 11+**：仅需**无障碍服务 + 悬浮窗**，功能完整度 100%
- ✅ **Android 7-10**：仅需**无障碍服务 + 悬浮窗**，功能完整度 95%（可选择安装 Shizuku 用于截图降级）

**关键特性**：
- ✨ 实时权限检测：权限状态自动更新，无需手动刷新
- 🚀 极简配置：2个必需权限（无障碍+悬浮窗），Android 11+ 即可获得完整体验
- 🎯 智能引导：优化的欢迎页面和权限设置流程

> 📖 详细技术分析请查看：[架构文档](docs/ARCHITECTURE.md)

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
│  │  WelcomePage│ │PermissionPg  │ │TaskHistoryPg │  │
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
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┐  │
│  │ Accessibility│ │DeviceControl │ │Shizuku(可选)│  │
│  │   Service    │ │  (降级策略)  │ │             │  │
│  └──────────────┘ └──────────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────┘

降级策略：
  截图：AccessibilityService (Android 11+) → Shizuku
  触摸：AccessibilityService GestureAPI → Shizuku InputManager
  文本：AccessibilityService ACTION_SET_TEXT → Shizuku ADB Keyboard
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

| 环境 | 最低要求 | 推荐版本 |
|-----|---------|---------|
| **Android** | 9.0+ (API 28) | 11.0+ (API 30) |
| **Flutter** | 3.10+ | 最新稳定版 |
| **Shizuku** | 13.0+ | 最新版（可选） |

### 2. 安装应用

#### 方式一：从源码构建
```bash
# 克隆仓库
git clone https://github.com/your-repo/Auto-GLM-Android.git
cd Auto-GLM-Android

# 安装依赖
flutter pub get

# 构建并运行
flutter run
```

#### 方式二：安装 APK
从 [Releases](https://github.com/your-repo/Auto-GLM-Android/releases) 下载最新 APK 安装。

### 3. 权限配置（自动实时检测）

应用会实时检测权限状态，配置完成后自动进入主页。

#### 必需权限

**1. 无障碍服务**（必需）
- 用途：模拟点击、滑动、文本输入
- 配置：应用内点击跳转到系统设置开启
- 说明：一次开启永久有效

**2. 悬浮窗权限**（必需）
- 用途：显示任务执行状态
- 配置：应用内点击跳转到系统设置授权

#### 可选权限

**3. Shizuku**（可选，Android 7-10 推荐用于截图降级）

**通过无线调试启动（推荐）**：
1. 安装 [Shizuku 应用](https://shizuku.rikka.app/)
2. 在手机"开发者选项"中开启"无线调试"
3. 在 Shizuku 应用中按提示配对并启动服务
4. 在 AutoGLM 中授权 Shizuku

**通过 ADB 启动（需要电脑）**：
```bash
# 连接手机到电脑
adb devices

# 启动 Shizuku 服务
adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh

# 返回手机在 AutoGLM 中授权
```

> 💡 **提示**：Shizuku 重启后需要重新激活，建议使用无线调试方式，手机端可自行激活。

### 4. 配置模型API

在应用"设置"页面配置：

| 配置项 | 值 | 说明 |
|-------|---|------|
| **API URL** | `https://api-inference.modelscope.cn/v1` | 魔搭社区推理API |
| **API Key** | 在[魔搭社区](https://www.modelscope.cn)获取 | 必须填写，否则无法使用 |
| **模型名称** | `ZhipuAI/AutoGLM-Phone-9B` | 默认值，可选其他兼容模型 |

**获取 API Key**：
1. 访问 [魔搭社区](https://www.modelscope.cn)
2. 注册/登录账号
3. 进入"个人中心" → "访问令牌"
4. 复制 Token 粘贴到应用设置中

> ⚠️ **重要**：默认配置不含 API Key，必须自行填写才能使用 AI 功能。

### 5. 开始使用

1. 在主页输入任务描述，例如：
   - "打开微信给张三发消息说明天见"
   - "打开淘宝搜索机械键盘"
   - "打开抖音刷10分钟视频"

2. 点击"开始执行"，AI 会自动控制手机完成任务

3. 在"任务历史"中查看执行记录

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
| **SettingsPage** | 模型配置、Agent配置、权限状态 |
| **AppsListPage** | 查看100+支持的应用（分类筛选） |
| **TaskHistoryPage** | 任务历史记录和复用 |
| **PermissionSetupPage** | 统一的权限配置引导页 |
| **ShizukuSetupPage** | Shizuku 安装和配置引导（可选） |

## 📄 许可证

继承原 Open-AutoGLM 项目许可证。
