import 'package:flutter/material.dart';
import '../../../../core/security.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Vui lòng nhập đầy đủ email và mật khẩu");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthService().login(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = "Sai email hoặc mật khẩu";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              _LogoWidget(),
              const SizedBox(height: 60),
              Text("Chào mừng trở lại", style: theme.textTheme.headlineLarge),
              const SizedBox(height: 12),
              const Text(
                "Vui lòng nhập thông tin tài khoản của bạn",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              _InputField(
                controller: _emailController,
                label: "ĐỊA CHỈ EMAIL",
                hint: "name@deepcode.vn",
                icon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              _InputField(
                controller: _passwordController,
                label: "MẬT KHẨU",
                hint: "••••••••",
                icon: Icons.lock_outline,
                obscure: true,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "ĐĂNG NHẬP HỆ THỐNG",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 160),
              const Text(
                "POWERED BY DEEPCODE © 2026",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "DC",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "DEEPCODE",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Colors.blueGrey,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.blueAccent.shade100,
                size: 20,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
