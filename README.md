# AutoZi

<p align="center">
  <img src="icon.png" width="120" alt="AutoZi Logo">
</p>

<p align="center">
  <b>AI驱动的手机自动化助手</b>
</p>

<p align="center">
  用自然语言控制你的Android手机，让AI帮你完成复杂操作
</p>

---

## ✨ 功能特点

- 🤖 **自然语言控制** - 用日常语言描述任务，AI自动理解并执行
- 📱 **屏幕理解** - 实时分析屏幕内容，智能识别UI元素
- 👆 **模拟操作** - 自动执行点击、滑动、输入等操作
- ⌨️ **内置输入法** - 支持可靠的中文输入，无需额外安装
- 🔐 **隐私安全** - 所有操作本地执行，数据不上传

## 📋 系统要求

- Android 9.0 (API 28) 或更高版本
- 智谱 API Key（用于调用 AutoGLM 模型）

## 🚀 快速开始

### 1. 下载安装

从 [Releases](https://github.com/king0929zion/Auto-GLM-Android/releases) 页面下载最新版本的 APK 文件并安装。

### 2. 配置 API Key

1. 访问 [智谱开放平台](https://bigmodel.cn/usercenter/proj-mgmt/apikeys) 获取 API Key
2. 在应用设置中填入 API Key

### 3. 授予权限

AutoZi 需要完全控制您的设备以执行自动化任务，因此以下权限均为 **必需**：

1. **无障碍服务** - 用于读取屏幕内容、模拟点击和滑动
2. **悬浮窗权限** - 用于显示任务执行状态和控制面板
3. **Shizuku 授权** - 用于执行高级系统操作和可靠的文本输入

---

## 📦 核心特性

- **极简设计** - 全新的黑白极简 UI，专注任务本身
- **可靠输入** - 结合 Shizuku 和 Android 原生能力，提供稳定的文本输入
- **全场景覆盖** - 支持微信、淘宝、美团等主流应用的自动化操作

---

## 📋 权限说明

| 权限 | 必需 | 说明 |
|------|:----:|------|
| 无障碍服务 | ✅ | 核心能力：读屏、点击、滑动 |
| 悬浮窗 | ✅ | 交互界面：状态显示、任务控制 |
| Shizuku | ✅ | 高级能力：输入法切换、ADB指令执行 |
| 电池优化白名单 | ⚠️ | 强烈推荐开启，防止服务被杀 |

## 🛠️ 构建项目

### 环境要求

- Flutter 3.5.0 或更高版本
- Android SDK 36
- JDK 17

### 构建步骤

```bash
# 克隆项目
git clone https://github.com/king0929zion/Auto-GLM-Android.git
cd Auto-GLM-Android

# 安装依赖
flutter pub get

# 构建 Release APK
flutter build apk --release
```

## 📂 项目结构

```
lib/
├── config/          # 配置文件
├── core/            # 核心逻辑（Agent、Action解析）
├── data/            # 数据模型
├── services/        # 服务层（设备控制、模型调用）
└── ui/              # 用户界面
    ├── screens/     # 页面
    ├── theme/       # 主题
    └── widgets/     # 组件

android/
└── app/src/main/kotlin/
    └── com/autoglm/auto_glm_mobile/
        ├── MainActivity.kt              # 主Activity
        ├── DeviceController.kt           # 设备控制
        ├── AutoGLMAccessibilityService.kt # 无障碍服务
        ├── AutoZiInputMethod.kt          # 内置输入法 ✨
        ├── KeepAliveService.kt           # 保活服务
        └── FloatingWindowService.kt      # 悬浮窗服务
```

## 📄 开源协议

本项目基于 MIT 协议开源。

## 🙏 致谢

- [智谱AI](https://bigmodel.cn/) - 提供 AutoGLM 模型
- [Shizuku](https://shizuku.rikka.app/) - 提供系统级能力
- [Flutter](https://flutter.dev/) - 跨平台开发框架
