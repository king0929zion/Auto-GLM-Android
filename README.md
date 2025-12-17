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

**必需权限：**
- ✅ **无障碍服务** - 用于模拟点击、滑动和输入

**可选权限（推荐）：**
- 🔋 **电池优化白名单** - 防止无障碍服务被系统关闭
- 🔲 **悬浮窗** - 显示任务执行状态
- 🔐 **Shizuku** - 提供更可靠的输入能力（特别是微信等应用）

## 📦 权限说明

### 无障碍服务（必需）

AutoZi 需要无障碍服务权限来：
- 读取屏幕内容进行 AI 分析
- 模拟触摸事件（点击、滑动）
- 在输入框中输入文字

### Shizuku（可选，推荐）

如果启用 Shizuku，AutoZi 将优先使用剪贴板+粘贴的方式输入文字，这对于微信等有输入限制的应用更加可靠。

**配置 Shizuku：**
1. 下载安装 [Shizuku](https://shizuku.rikka.app/)
2. 按照 Shizuku 应用内的说明启动服务
3. 返回 AutoZi 授权

### 电池优化白名单（可选，强烈推荐）

部分国产 ROM（小米、华为、OPPO、vivo 等）会在应用被划掉后自动关闭无障碍服务。将 AutoZi 加入电池优化白名单可以防止这种情况。

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
        ├── KeepAliveService.kt           # 保活服务
        └── FloatingWindowService.kt      # 悬浮窗服务
```

## 📄 开源协议

本项目基于 MIT 协议开源。

## 🙏 致谢

- [智谱AI](https://bigmodel.cn/) - 提供 AutoGLM 模型
- [Shizuku](https://shizuku.rikka.app/) - 提供系统级能力
- [Flutter](https://flutter.dev/) - 跨平台开发框架
