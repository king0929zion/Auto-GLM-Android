/// 预设模型供应商配置
/// 所有供应商均使用 OpenAI 兼容格式

class DefaultProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String? description;
  final bool isBuiltIn;
  
  const DefaultProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.description,
    this.isBuiltIn = true,
  });
}

/// 预设供应商列表
const List<DefaultProvider> defaultProviders = [
  DefaultProvider(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    description: 'GPT-4o, GPT-4, GPT-3.5 Turbo 等',
  ),
  DefaultProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    description: 'DeepSeek V3, DeepSeek R1 等',
  ),
  DefaultProvider(
    id: 'siliconflow',
    name: '硅基流动',
    baseUrl: 'https://api.siliconflow.cn/v1',
    description: 'Qwen, GLM, Llama 等模型',
  ),
  DefaultProvider(
    id: 'zhipu',
    name: '智谱AI',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    description: 'GLM-4, GLM-4V 等',
  ),
  DefaultProvider(
    id: 'nvidia',
    name: 'NVIDIA NIM',
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    description: 'Llama, Mistral, Nemotron 等',
  ),
  DefaultProvider(
    id: 'modelscope',
    name: '魔搭 ModelScope',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    description: '通义千问, Qwen 系列',
  ),
  DefaultProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    description: '聚合多家模型供应商',
  ),
];
