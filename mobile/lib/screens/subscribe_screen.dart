import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key, required this.api, this.user, this.onDone});

  final ApiClient api;
  /// When set, used to block non-student accounts before calling Paystack.
  final Map<String, dynamic>? user;
  final VoidCallback? onDone;

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 4);
  static const int _maxPollTicks = 45;

  List<dynamic> _packages = [];
  String _currency = 'KES';
  String? _error;
  bool _loading = true;
  final _ref = TextEditingController();

  Timer? _pollTimer;
  String? _pendingReference;
  bool _checkingPayment = false;
  int _pollTicks = 0;

  String _formatPrice(int minor, String currency) {
    final major = minor / 100.0;
    switch (currency.toUpperCase()) {
      case 'KES':
        return 'Ksh ${major.toStringAsFixed(0)}';
      case 'NGN':
        return '₦${major.toStringAsFixed(0)}';
      default:
        return '$currency ${major.toStringAsFixed(2)}';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _stopPremiumPolling();
    WidgetsBinding.instance.removeObserver(this);
    _ref.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingReference != null &&
        _checkingPayment) {
      unawaited(_pollPremiumOnce());
    }
  }

  void _stopPremiumPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollTicks = 0;
    if (mounted) {
      setState(() => _checkingPayment = false);
    } else {
      _checkingPayment = false;
    }
  }

  void _startPremiumPolling(String reference) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollTicks = 0;
    _pendingReference = reference;
    if (!mounted) return;
    setState(() {
      _checkingPayment = true;
      _error = null;
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      _pollTicks++;
      if (_pollTicks > _maxPollTicks) {
        _stopPremiumPolling();
        if (mounted) {
          final pending = _pendingReference;
          setState(() {
            _error =
                'Payment not confirmed yet. Check your Paystack SMS or email for the reference, or tap Retry after completing payment.';
            if (pending != null && _ref.text.trim().isEmpty) {
              _ref.text = pending;
            }
          });
        }
        return;
      }
      await _pollPremiumOnce();
    });
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), _pollPremiumOnce),
    );
  }

  Future<void> _pollPremiumOnce() async {
    final ref = _pendingReference;
    if (ref == null || ref.isEmpty || !mounted) return;
    try {
      await widget.api.verifyPayment(ref);
      if (!mounted) return;
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollTicks = 0;
      _pendingReference = null;
      setState(() => _checkingPayment = false);
      widget.onDone?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium activated')),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != null && code != 400 && code != 403 && mounted) {
        setState(() {
          _error = ApiClient.dioErrorMessage(
            e,
            fallback: 'Could not confirm payment. Try again or use reference below.',
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      await ApiClient.pokeHealthEndpoint();
      if (!mounted) return;
      final data = await widget.api.fetchPackages();
      final list = data['packages'] as List<dynamic>? ?? [];
      final cur = ((data['currency'] as String?) ?? 'KES').toUpperCase();
      setState(() {
        _packages = list;
        _currency = cur;
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

  Future<bool?> _showSignInDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign in to continue',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: const Text(
          'Payments use your student account. Log in or create one, then you can pay with Paystack.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log in or register'),
          ),
        ],
      ),
    );
  }

  /// Returns true when the user may call payment APIs (has token + student when [user] is known).
  Future<bool> _ensureAuthenticatedForPayment() async {
    final token = await ApiClient.getToken();
    if (token != null && token.isNotEmpty) {
      if (widget.user != null && widget.user!['role'] != 'student') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only student accounts can purchase Premium. Sign in with a student account.'),
            ),
          );
        }
        return false;
      }
      return true;
    }
    if (!mounted) return false;
    final go = await _showSignInDialog();
    if (go != true || !mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
    if (ok != true || !mounted) return false;
    widget.onDone?.call();
    return true;
  }

  Future<void> _pay(Map<String, dynamic> pkg) async {
    if (!await _ensureAuthenticatedForPayment()) return;
    setState(() => _error = null);
    try {
      final init = await widget.api.initializePayment(pkg['id'] as String);
      final url = Uri.parse(init['authorizationUrl'] as String);
      final reference = (init['reference'] as String?)?.trim();
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        setState(() => _error = 'Could not open browser.');
        return;
      }
      if (reference != null && reference.isNotEmpty) {
        _startPremiumPolling(reference);
      }
    } catch (e) {
      setState(() {
        _error = ApiClient.dioErrorMessage(
          e,
          fallback: 'Payment start failed. Log in as a student and check Paystack keys.',
        );
      });
    }
  }

  Future<void> _verify() async {
    if (!await _ensureAuthenticatedForPayment()) return;
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
    } catch (e) {
      setState(() {
        _error = ApiClient.dioErrorMessage(e, fallback: 'Verification failed. Check reference.');
      });
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: AppColors.spotifyGreen, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Study without interruptions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Remove ads on PDFs and audio. Pay securely with Paystack ($_currency).',
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pay in the browser. When you return to the app, we confirm Premium automatically (no need to paste the reference).',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (_checkingPayment) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Waiting for payment…',
                          style: TextStyle(
                            color: AppColors.spotifyGreen.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                                      _formatPrice(kobo, _currency),
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
                  'Still waiting?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'If automatic confirmation does not run, paste the Paystack reference.',
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.95), height: 1.35),
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
