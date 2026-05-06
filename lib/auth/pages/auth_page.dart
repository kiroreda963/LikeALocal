import 'package:flutter/material.dart';
import '../auth_provider.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
 
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
 
class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
 
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }
 
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 60),
          // Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _AuthTabBar(controller: _tabController),
          ),
          const SizedBox(height: 8),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                LoginPage(onSwitchToSignup: () => _tabController.animateTo(1)),
                SignupPage(onSwitchToSignin: () => _tabController.animateTo(0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _AuthTabBar extends StatelessWidget {
  final TabController controller;
  const _AuthTabBar({required this.controller});
 
  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      labelColor: Colors.black,
      unselectedLabelColor: Colors.grey.shade400,
      labelStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 2, color: Colors.black),
        insets: EdgeInsets.symmetric(horizontal: 16),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: 'Log in'),
        Tab(text: 'Sign up'),
      ],
    );
  }
}
 
// ─── LOGIN PAGE ────────────────────────────────────────────────────────────────
 
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSwitchToSignup});

  final VoidCallback onSwitchToSignup;
  @override
  State<LoginPage> createState() => _LoginPageState();
}
 
class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _wrongPassword = false;
 
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
 
  void _onContinue() {
    // Simulate wrong password for demonstration
    setState(() {
      _wrongPassword = _passwordController.text.isNotEmpty &&
          _passwordController.text != 'correct';
    });
  }
 
  @override
  Widget build(BuildContext context) {
final authProvider = Provider.of<AuthProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _FieldLabel('Your Email'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _emailController,
            hint: 'your@email.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _FieldLabel('Password'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _passwordController,
            hint: '••••••••••',
            obscureText: _obscurePassword,
            hasError: _wrongPassword,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
            onChanged: (_) {
              if (_wrongPassword) {
                setState(() => _wrongPassword = false);
              }
            },
          ),
          if (_wrongPassword) ...[
            const SizedBox(height: 6),
            const Text(
              'Wrong password',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _ContinueButton(onPressed: () async {
            String? error = await authProvider.login(
              _emailController.text,
              _passwordController.text,
            );
            if (error != null) {
              setState(() => _wrongPassword = true);
            } else {
              print('Login successful');
            }
          }),
          const SizedBox(height: 48),
          _BottomText(
            prefix: "Don't have an account? ",
            action: 'Sign up',
            onTap: widget.onSwitchToSignup,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
 
// ─── SIGN UP PAGE ──────────────────────────────────────────────────────────────
 
class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.onSwitchToSignin});

  final VoidCallback onSwitchToSignin;
  @override
  State<SignupPage> createState() => _SignupPageState();
}
 
class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
 
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _FieldLabel('Name'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _nameController,
            hint: 'Your full name',
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 20),
          _FieldLabel('Email Address'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _emailController,
            hint: 'your@email.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _FieldLabel('Phone Number'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _phoneController,
            hint: '+201XXXXXXXXX',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _FieldLabel('Password'),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: _passwordController,
            hint: '••••••••••',
            obscureText: _obscurePassword,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _ContinueButton(onPressed: () async {
            String? error = await authProvider.signUp(
              _emailController.text,
              _passwordController.text,
            );
            print(error ?? 'Sign up successful');
          }),
          const SizedBox(height: 48),
          _BottomText(
            prefix: 'Already have an account? ',
            action: 'Sign in',
            onTap: widget.onSwitchToSignin,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
 
// ─── SHARED WIDGETS ────────────────────────────────────────────────────────────
 
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
 
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        letterSpacing: 0.1,
      ),
    );
  }
}
 
class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final bool hasError;
  final TextInputType keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
 
  const _AuthTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.hasError = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.onChanged,
  });
 
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black87,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFD32F2F)
                : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFD32F2F) : Colors.black87,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFD32F2F),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
 
class _ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ContinueButton({required this.onPressed});
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
 
class _BottomText extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;
 
  const _BottomText({
    required this.prefix,
    required this.action,
    required this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          text: prefix,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }}