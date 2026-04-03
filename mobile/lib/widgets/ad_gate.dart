import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const int kAdSeconds = 30;

Future<void> showAdGate(BuildContext context, {String title = 'Sponsored'}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (ctx) => _AdGateDialog(title: title),
  );
}

class _AdGateDialog extends StatefulWidget {
  const _AdGateDialog({required this.title});

  final String title;

  @override
  State<_AdGateDialog> createState() => _AdGateDialogState();
}

class _AdGateDialogState extends State<_AdGateDialog> {
  int _left = kAdSeconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        _t?.cancel();
        setState(() => _left = 0);
        return;
      }
      setState(() => _left -= 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppColors.spotifyGreen.withValues(alpha: 0.35),
                  AppColors.bgHighlight,
                ],
              ),
            ),
            child: const Text(
              'Demo ad\nReplace with your ad network',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Continue in $_left s or skip now',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip ad'),
        ),
      ],
    );
  }
}
