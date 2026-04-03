import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfx/pdfx.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/app_log.dart';
import '../util/url_resolve.dart';
import '../widgets/ad_gate.dart';

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({
    super.key,
    required this.api,
    required this.slug,
    required this.premium,
  });

  final ApiClient api;
  final String slug;
  final bool premium;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  Map<String, dynamic>? _topic;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await widget.api.fetchTopic(widget.slug);
      setState(() => _topic = t);
    } catch (e, st) {
      medstudyLogError('TopicDetailScreen.fetchTopic("${widget.slug}")', e, st);
      var msg = 'Could not load topic. Check console / Run log for [medstudy].';
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 404) {
          msg = 'Topic not found (404). Check slug and that the topic is published in admin.';
        } else if (code != null) {
          msg = 'Server error ($code). API: ${AppConfig.apiBase}';
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Loading…'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }
    final t = _topic!;
    final title = t['title'] as String? ?? '';
    final pdfUrl = t['pdfUrl'] as String?;
    final audioUrl = t['audioUrl'] as String?;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.spotifyGreen.withValues(alpha: 0.28),
                  AppColors.bgBase,
                ],
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'PDF'),
              Tab(text: 'Audio'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PdfPane(
              api: widget.api,
              pdfUrl: pdfUrl != null ? resolveHostUrl(pdfUrl) : null,
              premium: widget.premium,
            ),
            _AudioPane(
              audioUrl: audioUrl != null ? resolveHostUrl(audioUrl) : null,
              premium: widget.premium,
              title: title,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPane extends StatefulWidget {
  const _PdfPane({required this.api, required this.pdfUrl, required this.premium});

  final ApiClient api;
  final String? pdfUrl;
  final bool premium;

  @override
  State<_PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<_PdfPane> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _err;
  String _statusLine = 'Preparing…';
  int _bytesReceived = 0;
  int? _bytesTotal;
  int _lastProgressBucket = -1;
  VoidCallback? _pageListener;
  final Set<int> _adShownFor = {};

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = widget.pdfUrl;
    if (url == null) {
      setState(() {
        _loading = false;
        _err = 'No PDF for this topic.';
      });
      return;
    }
    medstudyLog('PDF opening: $url');
    try {
      if (mounted) {
        setState(() {
          _statusLine = 'Waking server… (Render free tier can take 1–3 min when asleep)';
        });
      }
      await ApiClient.pokeHealthEndpoint();
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _statusLine = 'Downloading PDF…';
          _bytesReceived = 0;
          _bytesTotal = null;
          _lastProgressBucket = -1;
        });
      }

      final bytes = await widget.api.downloadBytes(
        url,
        onProgress: (received, total) {
          if (!mounted) return;
          final bucket = received ~/ (300 * 1024);
          final done = total != null && received >= total && total > 0;
          if (bucket == _lastProgressBucket && !done) return;
          _lastProgressBucket = bucket;
          setState(() {
            _bytesReceived = received;
            _bytesTotal = total;
            if (total != null && total > 0) {
              final pct = (100 * received / total).clamp(0, 100).toStringAsFixed(0);
              _statusLine = 'Downloading… $pct%';
            } else {
              final mb = received / (1024 * 1024);
              _statusLine = 'Downloading… ${mb.toStringAsFixed(1)} MB';
            }
          });
        },
      );
      if (!mounted) return;

      if (mounted) {
        setState(() => _statusLine = 'Opening PDF…');
      }
      final pdfDoc = await PdfDocument.openData(bytes);
      if (!mounted) return;

      final c = PdfControllerPinch(document: Future.value(pdfDoc));
      _controller = c;
      if (!widget.premium) {
        void listener() {
          final p = c.pageListenable.value;
          if (p > 0 && p % 3 == 0 && !_adShownFor.contains(p)) {
            _adShownFor.add(p);
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await showAdGate(context, title: 'Reading break');
            });
          }
        }

        _pageListener = listener;
        c.pageListenable.addListener(listener);
      }
      setState(() => _loading = false);
    } on TimeoutException catch (_) {
      setState(() {
        _loading = false;
        _err =
            'PDF download took too long (15 min). Try again on Wi‑Fi, or upgrade Render so the app does not sleep.';
      });
    } catch (e, st) {
      medstudyLogError('PDF pane', e, st);
      String msg = 'Could not load PDF.';
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 404) {
          msg = 'PDF not found (404). On Render, re-upload with UPLOAD_DRIVER=gridfs — old disk files are deleted on restart.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg =
              'Connection timed out. Render may still be waking up — wait 2–3 min, go back, pull to refresh topics, then open again.';
        } else if (code != null) {
          msg = 'PDF failed (HTTP $code).';
        }
      }
      setState(() {
        _loading = false;
        _err = msg;
      });
    }
  }

  @override
  void dispose() {
    if (_controller != null && _pageListener != null) {
      _controller!.pageListenable.removeListener(_pageListener!);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final total = _bytesTotal;
      final received = _bytesReceived;
      double? progress;
      if (total != null && total > 0) {
        progress = (received / total).clamp(0.0, 1.0);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: progress != null ? 16 : 20),
              if (progress != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.bgHighlight,
                    color: AppColors.spotifyGreen,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _statusLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Free hosting often sleeps the API. First open after idle can take several minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }
    final c = _controller!;
    return Column(
      children: [
        if (!widget.premium)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Free: short ad on pages 3, 6, 9… Premium removes ads.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: PdfViewPinch(
            controller: c,
            scrollDirection: Axis.vertical,
          ),
        ),
      ],
    );
  }
}

class _AudioPane extends StatefulWidget {
  const _AudioPane({required this.audioUrl, required this.premium, required this.title});

  final String? audioUrl;
  final bool premium;
  final String title;

  @override
  State<_AudioPane> createState() => _AudioPaneState();
}

class _AudioPaneState extends State<_AudioPane> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  Duration _lastPos = Duration.zero;
  double _playedSinceAd = 0;
  double _nextAt = 60;
  bool _adOpen = false;
  String? _audioInitError;

  @override
  void initState() {
    super.initState();
    final url = widget.audioUrl;
    if (url != null) {
      _initAudio(url);
    }
  }

  Future<void> _initAudio(String url) async {
    medstudyLog('audio setUrl: $url');
    try {
      await _player.setUrl(url);
      if (!mounted) return;
      if (!widget.premium) {
        _posSub = _player.positionStream.listen((pos) {
          if (_adOpen || !mounted) return;
          final dt = (pos - _lastPos).inMilliseconds / 1000.0;
          if (dt > 0 && dt < 5) _playedSinceAd += dt;
          _lastPos = pos;
          if (_playedSinceAd >= _nextAt) {
            _triggerAd();
          }
        });
      }
    } catch (e, st) {
      medstudyLogError('audio setUrl', e, st);
      if (mounted) setState(() => _audioInitError = 'Could not load audio. See log: $e');
    }
  }

  Future<void> _triggerAd() async {
    if (_adOpen || !mounted) return;
    setState(() => _adOpen = true);
    await _player.pause();
    if (!mounted) return;
    await showAdGate(context, title: 'Audio break');
    if (!mounted) return;
    setState(() {
      _adOpen = false;
      _playedSinceAd = 0;
      _nextAt = 180;
    });
    await _player.play();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.audioUrl;
    if (url == null) {
      return const Center(
        child: Text('No audio for this topic.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final err = _audioInitError;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.premium)
            const Text(
              'Free: ad after ~1 min, then every ~3 min. Premium removes ads.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 32),
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return Center(
                child: Material(
                  color: AppColors.spotifyGreen,
                  shape: const CircleBorder(),
                  elevation: 8,
                  shadowColor: AppColors.spotifyGreen.withValues(alpha: 0.5),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: playing ? _player.pause : _player.play,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 56,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, snap) {
              final d = snap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, posSnap) {
                  final p = posSnap.data ?? Duration.zero;
                  return Text(
                    '${_fmt(p)} / ${_fmt(d)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
