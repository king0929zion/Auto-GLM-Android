# AutoZi

<p align="center">
  <img src="https://raw.githubusercontent.com/king0929zion/Auto-GLM-Android/main/assets/icon_rounded.png" width="120" alt="AutoZi Logo">
</p>

<p align="center">
  <b>AI驱动的手机自动化助手 / AI-Powered Mobile Automation Agent</b>
</p>

<p align="center">
  用自然语言控制你的Android手机，让AI帮你完成复杂操作
  <br>
  Control your Android phone with natural language; let AI handle the complex tasks for you.
</p>

---

## ✨ 更新 Feature Highlights

- **全面升级的 UI 设计 (Revamped UI)**: 全新极简黑白主题，融入微交互动画和高斯模糊效果，带来高级且流畅的视觉体验。
- **多语言支持 (Multi-language Support)**: 完整支持 **简体中文** 和 **English**，可一键切换语言环境。
- **智能对话模式 (Smart Chat)**: 类似 IM 的对话式任务交互，清晰展示 AI 思考过程 (Thinking) 和 执行步骤 (Action)。
- **OpenAI 兼容模型支持 (OpenAI-Compatible Models)**: 统一使用 OpenAI API 格式的模型供应商，配置更简单。
- **视觉反馈系统 (Visual Feedback)**: 
  - **悬浮球 (Floating Ball)**: 动态展示 AI 状态（思考中、执行中、空闲），支持拖拽。
  - **点击反馈 (Touch Feedback)**: 模拟人类操作的触控涟漪效果。
  - **打字机特效 (Typewriter Effect)**: 状态文字逐字显示，更具灵动感。

## 📱 功能特点 Core Features

- 🤖 **自然语言控制** - "帮我给妈妈发微信说晚上回家吃饭"，一句话搞定复杂链路。
- 👁️ **屏幕理解** - 基于多模态大模型，实时分析屏幕 UI 结构，精准识别按钮、文本框。
- 👆 **模拟操作** - 自动执行点击、滑动、长按、输入文本等操作，无需 Root（依赖无障碍服务）。
- ⌨️ **内置输入法** - 专为自动化优化的 **AutoZi Input Method**，确保中文输入的稳定性和准确性。
- 🛡️ **安全可靠** - 所有操作基于 Android 原生无障碍协议和 Shizuku 授权，过程透明可控。

## 📋 系统要求 System Requirements

- **Android 9.0 (API 28)** 或更高版本
- **Shizuku** (必需，用于高级权限授权)
- **AutoGLM API Key** (用于 Agent 自动化)
- **OpenAI 兼容模型 API Key** (用于主对话模型)

## 🚀 快速开始 Quick Start

### 1. 下载安装 (Download & Install)

从 [Releases](https://github.com/king0929zion/Auto-GLM-Android/releases) 页面下载最新版本的 APK 文件并安装。

### 2. 初始化设置 (Setup)

首次启动应用，AutoZi 会引导您完成必要的权限配置：
1. **无障碍服务 (Accessibility Service)**: 必须开启，用于核心控制。
2. **AutoZi 输入法 (Input Method)**: 必须启用并选为当前输入法，用于文本输入。
3. **Shizuku 授权**: 必须授权，用于执行系统级指令。
4. **悬浮窗权限 (Overlay)**: 推荐开启，用于显示可视化状态球。

### 3. 配置模型 (Configure Model)

进入 **设置 (Settings) -> 智能配置 (Intelligence)**:
1. 进入「模型配置」，选择 OpenAI 兼容的模型供应商并配置 API Key。
2. 进入「AutoGLM 配置」，填写 AutoGLM 的 API Key。
3. 点击保存。

### 4. 开始使用 (Start Using)

回到主页，在底部的输入框中输入您的指令，点击发送箭头。
> 示例："打开微信，查看最新的消息"
> 示例："在设置里把屏幕亮度调到最亮"

---

## 📂 项目结构 Project Structure

```
lib/
├── config/          # 全局配置、常量
├── core/            # Agent 核心逻辑 (Action Parser, Loop)
├── data/            # 数据层 (Models, Repositories)
├── l10n/            # 本地化资源 (AppStrings) ✨
├── services/        # 业务服务 (Device Control, LLM Service)
└── ui/              # 用户界面
    ├── screens/     # 全部页面 (Home, Settings, History)
    ├── theme/       # 主题定义 (Colors, TextStyles)
    └── widgets/     # 通用组件 (ThinkingCard, InputArea)

android/
└── app/src/main/kotlin/com/autoglm/auto_glm_mobile/
    ├── MainActivity.kt              # Flutter 桥接入口
    ├── DeviceController.kt          # Android原生控制 (Accessibility, ADB)
    ├── AutoGLMAccessibilityService.kt # 无障碍服务实现
    ├── AutoZiInputMethod.kt         # 自研输入法服务 ✨
    └── FloatingWindowService.kt     # 悬浮窗与状态显示 ✨
```

## 🛠️ 构建项目 Build from Source

### 环境要求 (Prerequisites)
- Flutter 3.x
- Android SDK 34+
- JDK 17

### 构建指令 (Build)

```bash
# 克隆项目
git clone https://github.com/king0929zion/Auto-GLM-Android.git
cd Auto-GLM-Android

# 安装依赖
flutter pub get

# 运行 (连接真机)
flutter run

# 构建 Release APK
flutter build apk --release
```

## 📄 开源协议 License

本项目基于 MIT 协议开源。

## 🙏 致谢 Acknowledgements

- [智谱AI (Zhipu AI)](https://bigmodel.cn/) - 强大的 AutoGLM 多模态模型支持
- [Shizuku](https://shizuku.rikka.app/) - 优雅的 Android 系统 API 调用方案
- [Flutter](https://flutter.dev/) - 构建精美跨平台 UI 的框架
