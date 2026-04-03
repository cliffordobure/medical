import 'package:flutter/material.dart';

import '../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = _register
          ? await widget.api.register(_email.text.trim(), _password.text)
          : await widget.api.login(_email.text.trim(), _password.text);
      final token = data['token'] as String?;
      if (token == null) throw Exception('No token');
      await ApiClient.saveToken(token);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _register ? 'Could not register.' : 'Invalid credentials.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Sign up' : 'Log in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password (min 8 for sign up)'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : (_register ? 'Create account' : 'Log in')),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _register = !_register),
              child: Text(_register ? 'Have an account? Log in' : 'New student? Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
