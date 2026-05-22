import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await ref.read(authServiceProvider).signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await ref.read(authServiceProvider).signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('google_login_fail')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithApple();
    } catch (e) {
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('apple_login_fail')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aiColor.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/images/app_icon.png', height: 100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n('welcome_back'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n('assistant_slogan'),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    label: context.l10n('email_label'),
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  _buildTextField(
                    controller: _passwordController,
                    label: context.l10n('password_label'),
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aiColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLogin ? context.l10n('login_btn') : context.l10n('register_btn'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Toggle Login/Signup
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? context.l10n('no_account_msg') : context.l10n('already_account_msg'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(context.l10n('or_continue_with'), style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Social Login Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        icon: Icons.g_mobiledata,
                        color: Colors.white10,
                        onTap: _signInWithGoogle,
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                        icon: Icons.apple,
                        color: Colors.white10,
                        onTap: _signInWithApple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegalLink(context.l10n('privacy_policy')),
                      const SizedBox(width: 16),
                      _buildLegalLink(context.l10n('terms_of_use')),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLink(String text) {
    return TextButton(
      onPressed: () {},
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.aiColor, width: 1),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return context.l10n('field_required_msg');
        return null;
      },
    );
  }

  Widget _buildSocialButton({
    String? iconPath,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: icon != null 
            ? Icon(icon, size: 36, color: Colors.white)
            : Image.asset(iconPath!, width: 28),
        ),
      ),
    );
  }
}
