import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../util/app_log.dart';
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
  String? _headline;
  bool _adLoadDone = false;
  bool _adFetchFailed = false;
  bool _imageLoading = false;
  bool _imageError = false;
  Uint8List? _imageBytes;

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
      final resolved = raw != null ? resolveMediaUrl(raw) : null;
      setState(() {
        _headline = line;
        _adLoadDone = true;
        _adFetchFailed = false;
        _imageBytes = null;
        _imageError = false;
        _imageLoading = resolved != null && resolved.isNotEmpty;
      });
      if (resolved != null && resolved.isNotEmpty) {
        await _loadImageBytes(resolved);
      } else {
        if (mounted) setState(() => _imageLoading = false);
      }
    } catch (e, st) {
      medstudyLogError('fetchInterstitialAd', e, st);
      if (mounted) {
        setState(() {
          _adLoadDone = true;
          _adFetchFailed = true;
          _imageLoading = false;
        });
      }
    }
  }

  /// [Image.network] often stays on a gray loading frame on Android; Dio matches PDF downloads.
  Future<void> _loadImageBytes(String url) async {
    final d = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: {
          'Accept': 'image/*,*/*',
          'User-Agent': 'MedStudyFlutter/1',
        },
      ),
    );
    try {
      final r = await d.get<List<int>>(url).timeout(const Duration(seconds: 50));
      final code = r.statusCode ?? 0;
      final data = r.data;
      if (code < 200 || code >= 300 || data == null || data.isEmpty) {
        throw DioException(
          requestOptions: r.requestOptions,
          message: 'Ad image HTTP $code, ${data?.length ?? 0} bytes',
        );
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = Uint8List.fromList(data);
        _imageLoading = false;
        _imageError = false;
      });
    } catch (e, st) {
      medstudyLogError('ad_gate image', e, st);
      if (mounted) {
        setState(() {
          _imageLoading = false;
          _imageError = true;
          _imageBytes = null;
        });
      }
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
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
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
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _canSkip ? () => Navigator.of(context).pop() : null,
                        child: Text(_canSkip ? 'Skip ad' : 'Skip in ${_skipIn}s'),
                      ),
                      if (!_canSkip)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Skip unlocks after $kSkipAfterSeconds seconds',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85), fontSize: 11),
                          ),
                        ),
                      const SizedBox(height: 12),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (_imageLoading) {
      return Container(
        color: AppColors.bgHighlight,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.spotifyGreen),
            ),
            SizedBox(height: 10),
            Text(
              'Loading image…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_imageError) {
      return _placeholder(imageLoadFailed: true);
    }
    final bytes = _imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ColoredBox(
        color: AppColors.bgHighlight,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(imageLoadFailed: true),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder({bool imageLoadFailed = false}) {
    final lines = _adFetchFailed
        ? [
            'Could not load ad from the API.',
            'Use the same backend as admin (app API_BASE = web VITE_API_URL). Redeploy server with /api/ads/interstitial.',
            'Host: ${AppConfig.apiBase}',
          ]
        : imageLoadFailed
            ? [
                'Image failed to load (URL or network).',
                'Re-upload the ad or check Cloudinary / file URLs on the server.',
              ]
            : [
                'No ad image for this break.',
                'Add one in Admin → Ads on the same server (${AppConfig.apiBase}).',
              ];
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
      child: Text(
        lines.join('\n'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12, height: 1.35),
      ),
    );
  }
}
