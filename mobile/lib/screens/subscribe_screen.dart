import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key, required this.api, this.onDone});

  final ApiClient api;
  final VoidCallback? onDone;

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  List<dynamic> _packages = [];
  String? _error;
  bool _loading = true;
  final _ref = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.fetchPackages();
      setState(() => _packages = data['packages'] as List<dynamic>? ?? []);
    } catch (_) {
      setState(() => _error = 'Could not load packages.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(Map<String, dynamic> pkg) async {
    setState(() => _error = null);
    try {
      final init = await widget.api.initializePayment(pkg['id'] as String);
      final url = Uri.parse(init['authorizationUrl'] as String);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        setState(() => _error = 'Could not open browser.');
      }
    } catch (_) {
      setState(() => _error = 'Payment start failed. Log in as a student and check Paystack keys.');
    }
  }

  Future<void> _verify() async {
    final r = _ref.text.trim();
    if (r.isEmpty) return;
    setState(() => _error = null);
    try {
      await widget.api.verifyPayment(r);
      if (!mounted) return;
      widget.onDone?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium activated')));
    } catch (_) {
      setState(() => _error = 'Verification failed. Check reference.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Pay with Paystack in the browser. After paying, paste the transaction reference here to verify '
                  '(or rely on the webhook + refresh).',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                ..._packages.map((p) {
                  final m = p as Map<String, dynamic>;
                  final kobo = (m['amountKobo'] as num).toInt();
                  return Card(
                    child: ListTile(
                      title: Text(m['displayName'] as String? ?? ''),
                      subtitle: Text('₦${(kobo / 100).toStringAsFixed(0)}'),
                      trailing: const Icon(Icons.payment),
                      onTap: () => _pay(m),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                const Text('Verify payment'),
                const SizedBox(height: 8),
                TextField(
                  controller: _ref,
                  decoration: const InputDecoration(
                    hintText: 'Reference from Paystack',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _verify, child: const Text('Verify reference')),
              ],
            ),
    );
  }
}
