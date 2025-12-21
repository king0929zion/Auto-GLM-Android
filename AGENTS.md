# Auto-GLM-Android 项目架构设计文档

## 1. 核心架构概述

### 1.1 项目定位
Auto-GLM-Android 是一个基于 AI 的移动端智能助手应用，支持普通对话模式和 Agent 自动化执行模式。

### 1.2 核心特性
- **虚拟屏幕执行**：所有自动化任务在虚拟屏幕中执行，不干扰用户正常使用
- **双模式架构**：普通对话模式 + Agent 自动化模式
- **模型灵活配置**：用户可自主选择和配置主对话模型

---

## 2. 模型配置架构

### 2.1 模型角色定义

#### 主对话模型（Primary Chat Model）
- **作用**：负责与用户的日常对话交互
- **配置方式**：用户可在设置中选择和配置
- **支持的模型**：
  - OpenAI GPT 系列
  - Google Gemini 系列
  - Anthropic Claude 系列
  - 智谱 GLM 系列
  - 其他兼容 OpenAI API 的模型

#### AutoGLM Agent（作为 Tool）
- **定位**：作为主对话模型的一个 Tool/Function
- **模型**：固定使用 `autoglm-phone`（来自智谱 BigModel 平台）
- **API 文档**：https://docs.bigmodel.cn/cn/guide/models/vlm/autoglm-phone
- **能力**：
  - 理解用户任务意图
  - 在虚拟屏幕中执行自动化操作
  - 返回执行结果和状态

### 2.2 工作流程

```
用户发送任务请求
    ↓
主对话模型接收请求
    ↓
判断：是否需要 Agent 执行？
    ├─ 否 → 主对话模型直接回复
    └─ 是 → 主对话模型简单确认 ("好的，我来帮你处理")
           ↓
       调用 AutoGLM Tool
           ↓
       AutoGLM 在虚拟屏幕执行任务
           ↓
       返回执行结果给主对话模型
           ↓
       主对话模型根据结果回复用户
```

### 2.3 Agent 模式开关
- **位置**：设置页面
- **控制逻辑**：
  - **关闭 Agent 模式**：
    - 主对话模型正常对话，不调用 AutoGLM Tool
    - 不启动虚拟屏幕
    - 纯文本对话体验
  - **开启 Agent 模式**：
    - 主对话模型可根据任务需求调用 AutoGLM Tool
    - 需要执行任务时启动虚拟屏幕
    - 任务完成后虚拟屏幕可保持或关闭（根据配置）

---

## 3. 虚拟屏幕执行架构

### 3.1 设计原则
- **不干扰用户**：所有自动化操作在虚拟屏幕执行
- **可视化监控**：用户可通过悬浮窗查看执行过程（可选）
- **独立环境**：虚拟屏幕与主屏幕完全隔离

### 3.2 技术实现（参考 Operit 项目）

#### 虚拟显示管理器（VirtualDisplayManager）
```kotlin
// 参考：g:/Open-AutoGLM/Operit/app/src/main/java/com/ai/assistance/operit/core/tools/agent/VirtualDisplayManager.kt

核心功能：
1. 创建虚拟显示（VirtualDisplay）
2. 管理 ImageReader 用于截图
3. 捕获虚拟屏幕内容
4. 生命周期管理（创建、释放）

关键 API：
- DisplayManager.createVirtualDisplay()
- ImageReader.newInstance()
- 截图：captureLatestFrameToFile()
```

#### 虚拟显示覆盖层（VirtualDisplayOverlay）
```kotlin
// 参考：g:/Open-AutoGLM/Operit/app/src/main/java/com/ai/assistance/operit/ui/common/displays/VirtualDisplayOverlay.kt

核心功能：
1. 悬浮窗展示虚拟屏幕内容
2. 支持窗口控制：
   - 拖动移动
   - 全屏/小窗切换
   - 贴边最小化
3. 触摸事件转发到虚拟屏幕
4. 自动化进度显示

显示模式：
- 全屏模式：填充整个屏幕，顶部右侧显示 Windows 风格控制按钮
- 小窗模式：左侧控制栏 + 右侧视频区域（0.4x 屏幕宽度）
- 贴边模式：最小化为侧边小手柄，点击恢复
```

### 3.3 执行流程

```
Agent 模式任务触发
    ↓
创建 VirtualDisplay
    ↓
启动 Shower 服务（屏幕镜像和控制）
    ↓
AutoGLM 在虚拟屏幕执行操作
    ↓
实时截图反馈给 AI 模型
    ↓
AI 模型分析并继续操作
    ↓
任务完成，返回结果
    ↓
关闭虚拟屏幕（或保持）
```

---

## 4. 主界面 UI 架构

### 4.1 主页面顶部布局（从左到右）

```
┌─────────────────────────────────────────────────────────┐
│  [历史记录]    [模型选择器]    [新建对话] [设置]      │
└─────────────────────────────────────────────────────────┘
```

#### 组件说明：

1. **历史记录按钮（最左侧）**
   - 图标：抽屉或历史记录图标
   - 功能：展开/收起历史对话列表
   - 列表内容：
     - 对话标题
     - 最后一条消息预览
     - 时间戳
     - 使用的模型标识

2. **模型选择器（中间）**
   - 显示内容：当前启用的主对话模型名称
   - 数据来源：实时从用户启用的主对话模型配置中读取
   - 交互方式：
     - 点击展开下拉列表或底部抽屉
     - 仅显示用户已启用的模型
     - 可快速切换当前对话使用的模型
   - 显示格式示例：
     - "GPT-4"
     - "Gemini Pro"
     - "GLM-4-Plus"

3. **新建对话按钮（右侧）**
   - 图标：加号或新建图标
   - 功能：创建新的对话会话
   - 行为：
     - 清空当前对话
     - 使用默认或上次选择的模型
     - 重置上下文

4. **设置按钮（最右侧）**
   - 图标：齿轮或设置图标
   - 功能：进入设置页面
   - 设置项包括：
     - 主对话模型配置（添加/删除/编辑）
     - Agent 模式开关
     - AutoGLM 配置
     - 虚拟屏幕设置
     - 权限管理

### 4.2 对话区域
- **普通对话模式**：
  - 标准的消息气泡展示
  - 用户消息 + AI 回复
  - 无虚拟屏幕相关 UI

- **Agent 执行模式**：
  - 显示任务执行状态卡片
  - 可选：显示虚拟屏幕小窗预览
  - 进度提示（"正在执行..."）
  - 执行结果展示

---

## 5. 模型配置管理

### 5.1 配置数据结构
```dart
class ModelConfig {
  String id;              // 唯一标识
  String name;            // 显示名称
  String provider;        // 提供商 (openai/google/anthropic/zhipu)
  String apiKey;          // API密钥
  String baseUrl;         // API基础URL
  String modelName;       // 模型名称
  bool enabled;           // 是否启用
  bool isDefault;         // 是否为默认模型
  Map<String, dynamic> extraParams; // 额外参数
}
```

### 5.2 配置管理器
```dart
class ModelConfigManager {
  // 获取所有已启用的模型
  List<ModelConfig> getEnabledModels();
  
  // 获取默认模型
  ModelConfig? getDefaultModel();
  
  // 设置默认模型
  void setDefaultModel(String modelId);
  
  // 添加模型配置
  void addModel(ModelConfig config);
  
  // 删除模型配置
  void removeModel(String modelId);
  
  // 更新模型配置
  void updateModel(ModelConfig config);
}
```

---

## 6. AutoGLM Tool 集成

### 6.1 Tool 定义（OpenAI Function Calling 格式）
```json
{
  "type": "function",
  "function": {
    "name": "autoglm_execute",
    "description": "在虚拟屏幕中执行移动端自动化任务，如打开应用、点击按钮、输入文字等操作",
    "parameters": {
      "type": "object",
      "properties": {
        "task_description": {
          "type": "string",
          "description": "需要执行的任务详细描述"
        },
        "expected_result": {
          "type": "string",
          "description": "期望的执行结果"
        }
      },
      "required": ["task_description"]
    }
  }
}
```

### 6.2 执行流程
1. 主对话模型决定调用 `autoglm_execute`
2. 应用层接收到 function call
3. 启动虚拟屏幕
4. 调用 AutoGLM API 执行任务
5. 实时更新执行状态
6. 返回结果给主对话模型
7. 主对话模型整理结果回复用户

---

## 7. 权限要求

### 7.1 必需权限
- **悬浮窗权限**（SYSTEM_ALERT_WINDOW）：显示虚拟屏幕悬浮窗
- **无障碍服务**（ACCESSIBILITY_SERVICE）：执行自动化操作
- **Shizuku 授权**：高级系统操作
- **通知权限**：任务状态通知

### 7.2 权限检查流程
参考现有的 `permission_setup_page.dart` 实现

---

## 8. 开发规范

### 8.1 目录结构
```
lib/
├── config/
│   └── model_config_manager.dart      # 模型配置管理
├── data/
│   └── models/
│       └── model_config.dart          # 模型配置数据模型
├── services/
│   ├── chat_service.dart              # 主对话服务
│   ├── autoglm_service.dart           # AutoGLM Agent 服务
│   └── virtual_display_service.dart   # 虚拟屏幕服务
├── ui/
│   ├── screens/
│   │   ├── home_page.dart             # 主页面
│   │   ├── settings_page.dart         # 设置页面
│   │   └── model_config_page.dart     # 模型配置页面
│   └── widgets/
│       ├── model_selector.dart        # 模型选择器组件
│       └── virtual_display_overlay.dart # 虚拟屏幕覆盖层
└── utils/
```

### 8.2 命名规范
- **文件名**：snake_case（如：`model_config_manager.dart`）
- **类名**：PascalCase（如：`ModelConfigManager`）
- **变量/函数**：camelCase（如：`getEnabledModels()`）
- **常量**：SCREAMING_SNAKE_CASE（如：`DEFAULT_MODEL_ID`）

### 8.3 代码风格
- 遵循 Dart 官方规范
- 使用 `flutter format` 格式化代码
- 所有公共 API 必须添加文档注释

---

## 9. 实现优先级

### Phase 1：基础架构
- [ ] 模型配置数据模型和管理器
- [ ] 主对话服务基础框架
- [ ] UI 顶部布局实现

### Phase 2：普通对话模式
- [ ] 集成各类主对话模型 API
- [ ] 对话历史管理
- [ ] 模型切换功能

### Phase 3：Agent 模式基础
- [ ] AutoGLM API 集成
- [ ] Function Calling 实现
- [ ] Agent 模式开关

### Phase 4：虚拟屏幕
- [ ] VirtualDisplay 管理器（参考 Operit）
- [ ] 虚拟屏幕悬浮窗 UI
- [ ] 触摸事件转发

### Phase 5：完整集成
- [ ] Agent 模式完整流程测试
- [ ] 错误处理和重试机制
- [ ] 性能优化

---

## 10. 参考资源

### 10.1 外部文档
- AutoGLM API：https://docs.bigmodel.cn/cn/guide/models/vlm/autoglm-phone
- OpenAI Function Calling：https://platform.openai.com/docs/guides/function-calling

### 10.2 内部参考
- Operit 虚拟屏幕实现：
  - `g:/Open-AutoGLM/Operit/app/src/main/java/com/ai/assistance/operit/core/tools/agent/VirtualDisplayManager.kt`
  - `g:/Open-AutoGLM/Operit/app/src/main/java/com/ai/assistance/operit/ui/common/displays/VirtualDisplayOverlay.kt`

---

## 11. 注意事项

### 11.1 虚拟屏幕
- **不要使用悬浮球**：所有任务在虚拟屏幕执行，不直接影响用户主屏幕
- **生命周期管理**：虚拟屏幕使用完毕后及时释放资源
- **性能优化**：避免不必要的截图和渲染

### 11.2 模型调用
- **API Key 安全**：使用加密存储，不要硬编码
- **错误处理**：网络异常、API 限流等情况的优雅降级
- **超时控制**：Agent 执行任务设置合理超时时间

### 11.3 用户体验
- **进度反馈**：实时显示任务执行状态
- **可中断性**：用户可随时暂停/取消 Agent 任务
- **结果可信度**：明确告知用户任务执行结果和可能的错误

---

*最后更新时间：2025-12-21*
