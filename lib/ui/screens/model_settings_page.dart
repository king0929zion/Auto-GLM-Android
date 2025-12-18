import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/settings_repository.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // AutoGLM Controllers
  final _autoglmKeyController = TextEditingController();

  // Doubao Controllers
  final _doubaoKeyController = TextEditingController();
  final _doubaoModelController = TextEditingController();

  bool _obscureAutoglmKey = true;
  bool _obscureDoubaoKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = SettingsRepository.instance;
    _autoglmKeyController.text = settings.autoglmApiKey;
    _doubaoKeyController.text = settings.doubaoApiKey;
    _doubaoModelController.text = settings.doubaoModelName;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    final settings = SettingsRepository.instance;
    await settings.setAutoglmApiKey(_autoglmKeyController.text.trim());
    await settings.setDoubaoApiKey(_doubaoKeyController.text.trim());
    await settings.setDoubaoModelName(_doubaoModelController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.scaffoldWhite,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(foregroundColor: AppTheme.primaryBlack),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlack)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // AutoGLM Section
            _buildSectionTitle('AutoGLM (Zhipu AI)'),
            _buildCard([
              _buildTextField(
                controller: _autoglmKeyController,
                label: 'API Key',
                hint: 'Enter Zhipu AI API Key',
                obscureText: _obscureAutoglmKey,
                onToggleObscure: () => setState(() => _obscureAutoglmKey = !_obscureAutoglmKey),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLink(
                text: 'Get API Key (BigModel)',
                url: 'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Doubao Section
             _buildSectionTitle('Doubao (Volcengine)'),
            _buildCard([
              _buildTextField(
                controller: _doubaoKeyController,
                label: 'API Key',
                hint: 'Enter Volcengine Ark API Key',
                obscureText: _obscureDoubaoKey,
                onToggleObscure: () => setState(() => _obscureDoubaoKey = !_obscureDoubaoKey),
              ),
              const Divider(height: 24),
              _buildTextField(
                 controller: _doubaoModelController,
                 label: 'Model Endpoint ID',
                 hint: 'e.g. doubao-seed-1-8...',
                 helperText: 'The endpoint ID, usually starts with "ep-" or custom name.',
              ),
              const SizedBox(height: 12),
               _buildLink(
                text: 'Get API Key (Volcengine)',
                url: 'https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperStyle: const TextStyle(color: AppTheme.textHint, fontSize: 11),
            filled: true,
            fillColor: AppTheme.grey50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.grey600,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLink({required String text, required String url}) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlack,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_outward, size: 14, color: AppTheme.primaryBlack),
        ],
      ),
    );
  }
}
