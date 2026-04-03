import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

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
      await ApiClient.pokeHealthEndpoint();
      if (!mounted) return;
      final data = await widget.api.fetchPackages();
      final list = data['packages'] as List<dynamic>? ?? [];
      setState(() {
        _packages = list;
        _error = null;
      });
    } catch (e) {
      var msg = ApiClient.connectionHint(e);
      if (e is FormatException) {
        msg = 'Invalid response from server. Redeploy the API or check ${AppConfig.apiBase}';
      }
      if (mounted) setState(() => _error = msg);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium activated')),
      );
    } catch (_) {
      setState(() => _error = 'Verification failed. Check reference.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Premium'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.spotifyGreen.withValues(alpha: 0.25),
                        AppColors.bgCard,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: AppColors.spotifyGreen, size: 36),
                      SizedBox(height: 12),
                      Text(
                        'Study without interruptions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Remove ads on PDFs and audio. Pay securely with Paystack.',
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pay in the browser, then verify with your reference if needed.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _load();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.spotifyGreen),
                    label: const Text('Retry', style: TextStyle(color: AppColors.spotifyGreen)),
                  ),
                ],
                const SizedBox(height: 20),
                if (_packages.isEmpty && _error == null) ...[
                  Text(
                    'No subscription plans are available. On the web admin, open Admin → Packages and ensure at least one package is active, then tap Retry.',
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.spotifyGreen),
                    label: const Text('Retry', style: TextStyle(color: AppColors.spotifyGreen)),
                  ),
                  const SizedBox(height: 8),
                ],
                ..._packages.map((p) {
                  final m = p as Map<String, dynamic>;
                  final kobo = (m['amountKobo'] as num).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _pay(m),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.spotifyGreen.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.payment_rounded, color: AppColors.spotifyGreen),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['displayName'] as String? ?? '',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${(kobo / 100).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.spotifyGreen,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 28),
                const Text(
                  'Verify payment',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ref,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Reference from Paystack',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verify,
                  child: const Text('VERIFY REFERENCE'),
                ),
              ],
            ),
    );
  }
}
