# GitHub Actions 自动编译配置指南

本项目使用 GitHub Actions 自动编译签名的 APK 和 AAB 文件。

## 🔧 配置步骤

### 0.（Windows / PowerShell）中文不乱码（推荐）

如果你在 PowerShell 中看到中文输出乱码，建议在执行命令前先设置 UTF-8：

```powershell
chcp 65001 | Out-Null
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

### 1. 准备签名密钥

你已经有了签名密钥 `my-release-key.keystore`，信息如下：
- **别名 (Key Alias)**: `mykey`
- **有效期**: 至 2053年

### 2. 将密钥转换为 Base64

在 PowerShell 中运行：

```powershell
# 转换为Base64
$bytes = [System.IO.File]::ReadAllBytes("C:\Users\Administrator\my-release-key.keystore")
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Out-File -FilePath "keystore_base64.txt" -Encoding ASCII

# 查看结果（复制这个内容）
Get-Content keystore_base64.txt
```

或者使用 Git Bash / Linux：

```bash
base64 -i my-release-key.keystore > keystore_base64.txt
cat keystore_base64.txt
```

### 3. 配置 GitHub Repository Secrets

在 GitHub 仓库中配置以下 Secrets：

1. 进入仓库页面
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**

添加以下 Secrets：

| Secret 名称 | 值 |
|-------------|---|
| `KEYSTORE_BASE64` | 步骤2中生成的 Base64 字符串 |
| `KEYSTORE_PASSWORD` | 你的密钥库密码 |
| `KEY_ALIAS` | `mykey` |
| `KEY_PASSWORD` | 你的密钥密码 |

### 4. 触发构建

构建会在以下情况自动触发：
- 推送到 `main` 或 `master` 分支
- 修改 `Auto-GLM-Android/` 目录下的文件
- 手动触发（在 Actions 页面点击 "Run workflow"）

### 5. 下载构建产物

1. 进入 **Actions** 页面
2. 点击最新的工作流运行
3. 在 **Artifacts** 区域下载 APK 或 AAB

## 📦 构建产物

每次成功构建会生成：

| 文件 | 说明 |
|------|------|
| `AutoGLM-Mobile-x.x.x.apk` | 已签名的 APK，可直接安装 |
| `app-release.aab` | Android App Bundle，用于 Google Play 发布 |

## 🚀 自动发布

当推送到 `main`/`master` 分支时，会自动：
1. 编译 Release APK
2. 创建 GitHub Release
3. 上传 APK 和 AAB 到 Release

## ⚠️ 安全注意事项

1. **永远不要**将 `key.properties` 或 `.keystore` 文件提交到 Git
2. Secrets 是加密存储的，只有 GitHub Actions 可以访问
3. 保管好你的密钥库文件，丢失后无法更新应用

## 🔍 问题排查

### 构建失败：找不到 keystore
确认 `KEYSTORE_BASE64` Secret 是正确的 Base64 编码。

### 签名失败：密码错误
检查 `KEYSTORE_PASSWORD` 和 `KEY_PASSWORD` 是否正确。

### 依赖下载失败
可能是网络问题，重新运行工作流。

## 📝 本地构建

如果需要本地构建，创建 `android/key.properties` 文件：

```properties
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=mykey
storeFile=my-release-key.keystore
```

然后将 keystore 文件复制到 `android/app/` 目录，运行：

```bash
cd Auto-GLM-Android
flutter build apk --release
```
