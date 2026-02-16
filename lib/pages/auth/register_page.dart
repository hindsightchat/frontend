// TODO: replace
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/dash');
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final response = await auth.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      context.go('/dash');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isAuthenticated) {
      // show empty scaffold while redirecting to avoid showing login page for a split second
      return const Scaffold();
    }

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Not welcome back',
                  style: context.theme.typography.xl2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Register a new account', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FTextField(
                  label: const Text('Username'),
                  hint: 'Enter your username',
                  suffixBuilder: (context, style, states) => Container(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('.hindsight.chat'),
                  ),
                  controller: _usernameController,
                ),
                const SizedBox(height: 16),
                FTextField.email(
                  label: const Text('Email'),
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 16),
                FTextFormField.password(
                  controller: _passwordController,
                  label: const Text('Password'),
                ),
                const SizedBox(height: 24),
                FButton(
                  onPress: auth.isLoading ? null : _handleRegister,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: 16),

                FButton(
                  onPress: auth.isLoading ? null : () => context.go('/login'),
                  child: const Text('Back to Login'),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 16),
                  FAlert(
                    icon: const Icon(Icons.error_outline),
                    title: const Text('Error'),
                    subtitle: Text(auth.error!),
                    style: FAlertStyle.destructive(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
