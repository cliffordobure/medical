import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/url_resolve.dart';

/// Total overlay timer (informational).
const int kAdCountdownSeconds = 30;

/// Skip button only after this many seconds.
const int kSkipAfterSeconds = 10;

Future<void> showAdGate(
  BuildContext context, {
  required ApiClient api,
  required VoidCallback onOpenSubscribe,
  String title = 'Sponsored',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (ctx) => _AdGateDialog(
      title: title,
      api: api,
      onOpenSubscribe: onOpenSubscribe,
    ),
  );
}

class _AdGateDialog extends StatefulWidget {
  const _AdGateDialog({
    required this.title,
    required this.api,
    required this.onOpenSubscribe,
  });

  final String title;
  final ApiClient api;
  final VoidCallback onOpenSubscribe;

  @override
  State<_AdGateDialog> createState() => _AdGateDialogState();
}

class _AdGateDialogState extends State<_AdGateDialog> {
  int _elapsed = 0;
  int _left = kAdCountdownSeconds;
  Timer? _t;
  String? _imageUrl;
  String? _headline;
  bool _adLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += 1;
        if (_left > 0) _left -= 1;
      });
    });
  }

  Future<void> _loadAd() async {
    try {
      final ad = await widget.api.fetchInterstitialAd();
      if (!mounted) return;
      final raw = ad?['imageUrl'] as String?;
      var line = (ad?['title'] as String?)?.trim();
      if (line != null && line.isEmpty) line = null;
      setState(() {
        _headline = line;
        _imageUrl = raw != null ? resolveMediaUrl(raw) : null;
        _adLoadDone = true;
      });
    } catch (_) {
      if (mounted) setState(() => _adLoadDone = true);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  bool get _canSkip => _elapsed >= kSkipAfterSeconds;
  int get _skipIn => (kSkipAfterSeconds - _elapsed).clamp(0, kSkipAfterSeconds);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_headline != null) ...[
              Text(
                _headline!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _adBody(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _canSkip
                  ? 'You can skip now · $_left s on timer'
                  : 'Skip available in $_skipIn s',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onOpenSubscribe();
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.spotifyGreen,
                side: const BorderSide(color: AppColors.spotifyGreen, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Subscribe — remove ads', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (!_canSkip)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Skip appears after $kSkipAfterSeconds seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_canSkip)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip ad'),
          ),
      ],
    );
  }

  Widget _adBody() {
    if (!_adLoadDone) {
      return Container(
        color: AppColors.bgHighlight,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.spotifyGreen),
        ),
      );
    }
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.bgHighlight,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.spotifyGreen, strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.spotifyGreen.withValues(alpha: 0.28),
            AppColors.bgHighlight,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: const Text(
        'Add sponsor images in Admin → Ads',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
