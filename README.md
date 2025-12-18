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
- ✅ **无障碍服务** - 用于模拟点击、滑动、基础输入

---

## 📦 输入方式

AutoZi 支持两种输入方式，根据配置自动选择：

### 方案一：无障碍服务（基础方案）

只需开启无障碍服务即可使用。

**适用场景：** 大多数应用的文字输入

### 方案二：Shizuku + ADB Keyboard（推荐方案）

配合 Shizuku 和 ADB Keyboard，提供更可靠的输入能力，特别适合微信等对无障碍输入有限制的应用。

**配置步骤：**

1. **安装 Shizuku**
   - 下载 [Shizuku](https://shizuku.rikka.app/)
   - 按照应用内说明启动服务（需要 ADB 或 root）

2. **安装 ADB Keyboard**
   - 下载 [ADB Keyboard APK](https://github.com/nicokosi/adb-keyboard/releases)
   - 安装后在系统设置 → 语言和输入法中**启用** ADB Keyboard

3. **授权 Shizuku**
   - 返回 AutoZi 设置页
   - 点击 Shizuku 项进行授权

**自动切换逻辑：**
- Shizuku 已授权 → 使用 ADB Keyboard（支持中文）
- Shizuku 未授权 → 使用无障碍服务

---

## 📋 权限说明

| 权限 | 必需 | 说明 |
|------|:----:|------|
| 无障碍服务 | ✅ | 读取屏幕、模拟点击、基础输入 |
| Shizuku | ❌ | 配合 ADB Keyboard 提供更可靠的输入 |
| 悬浮窗 | ❌ | 显示任务执行状态 |
| 电池优化白名单 | ❌ | 防止无障碍服务被系统关闭（强烈推荐） |

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
- [ADB Keyboard](https://github.com/nicokosi/adb-keyboard) - 可靠的文字输入
- [Flutter](https://flutter.dev/) - 跨平台开发框架
