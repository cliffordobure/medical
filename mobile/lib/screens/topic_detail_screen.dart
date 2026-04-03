import 'dart:async';

import 'package:audio_service/audio_service.dart';
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
import 'subscribe_screen.dart';

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({
    super.key,
    required this.api,
    required this.slug,
    required this.premium,
    this.onPremiumChanged,
  });

  final ApiClient api;
  final String slug;
  final bool premium;
  final VoidCallback? onPremiumChanged;

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
              pdfUrl: resolveMediaUrl(pdfUrl),
              premium: widget.premium,
              onPremiumChanged: widget.onPremiumChanged,
            ),
            _AudioPane(
              api: widget.api,
              audioUrl: resolveMediaUrl(audioUrl),
              premium: widget.premium,
              title: title,
              onPremiumChanged: widget.onPremiumChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPane extends StatefulWidget {
  const _PdfPane({
    required this.api,
    required this.pdfUrl,
    required this.premium,
    this.onPremiumChanged,
  });

  final ApiClient api;
  final String? pdfUrl;
  final bool premium;
  final VoidCallback? onPremiumChanged;

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
              await showAdGate(
                context,
                api: widget.api,
                title: 'Reading break',
                onOpenSubscribe: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SubscribeScreen(
                        api: widget.api,
                        onDone: widget.onPremiumChanged,
                      ),
                    ),
                  );
                },
              );
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
  const _AudioPane({
    required this.api,
    required this.audioUrl,
    required this.premium,
    required this.title,
    this.onPremiumChanged,
  });

  final ApiClient api;
  final String? audioUrl;
  final bool premium;
  final String title;
  final VoidCallback? onPremiumChanged;

  @override
  State<_AudioPane> createState() => _AudioPaneState();
}

class _AudioPaneState extends State<_AudioPane> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;

  /// Ads fire when playback position advances this many seconds beyond [_lastAdAnchor].
  /// First break ~1 min, then ~3 min (same as before).
  int _nextAdIntervalSec = 60;

  /// Start of the current “ad-free segment” on the timeline (handles seeks forward/back).
  Duration _lastAdAnchor = Duration.zero;
  Duration _lastReportedPos = Duration.zero;
  bool _adOpen = false;
  String? _audioInitError;
  bool _sliderDragging = false;
  double _sliderDragValue = 0;

  @override
  void initState() {
    super.initState();
    final url = widget.audioUrl;
    if (url != null) {
      _initAudio(url);
    }
  }

  Future<void> _initAudio(String url) async {
    medstudyLog('audio setAudioSource: $url');
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: url,
            title: widget.title,
            artist: 'MedStudy',
          ),
        ),
      );
      if (!mounted) return;
      _lastAdAnchor = Duration.zero;
      _lastReportedPos = Duration.zero;
      _nextAdIntervalSec = 60;
      if (!widget.premium) {
        _posSub = _player.positionStream.listen(_onPositionForAds);
      }
    } catch (e, st) {
      medstudyLogError('audio setAudioSource', e, st);
      if (mounted) setState(() => _audioInitError = 'Could not load audio. See log: $e');
    }
  }

  void _onPositionForAds(Duration pos) {
    if (_adOpen || !mounted) return;
    final back = _lastReportedPos - pos;
    if (back.inMilliseconds > 2000) {
      _lastAdAnchor = pos;
    }
    _lastReportedPos = pos;
    final forward = pos - _lastAdAnchor;
    if (forward.inSeconds >= _nextAdIntervalSec) {
      _triggerAd();
    }
  }

  Future<void> _triggerAd() async {
    if (_adOpen || !mounted) return;
    setState(() => _adOpen = true);
    await _player.pause();
    if (!mounted) return;
    await showAdGate(
      context,
      api: widget.api,
      title: 'Audio break',
      onOpenSubscribe: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SubscribeScreen(
              api: widget.api,
              onDone: widget.onPremiumChanged,
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    final p = _player.position;
    setState(() {
      _adOpen = false;
      _lastAdAnchor = p;
      _lastReportedPos = p;
      _nextAdIntervalSec = 180;
    });
    await _player.play();
  }

  Future<void> _skipSeconds(int seconds) async {
    final d = _player.duration ?? Duration.zero;
    if (d == Duration.zero) return;
    var p = _player.position + Duration(seconds: seconds);
    if (p < Duration.zero) p = Duration.zero;
    if (p > d) p = d;
    await _player.seek(p);
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

    final title = widget.title.trim();
    final safeTitle = title.isEmpty ? 'Topic' : title;

    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = (constraints.maxWidth - 48).clamp(220.0, 320.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.premium) _FreeAudioBanner(),
                if (!widget.premium) const SizedBox(height: 20),
                Center(
                  child: _AlbumArtCard(size: artSize),
                ),
                const SizedBox(height: 28),
                Text(
                  safeTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Topic audio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 28),
                StreamBuilder<ProcessingState>(
                  stream: _player.processingStateStream,
                  builder: (context, procSnap) {
                    final proc = procSnap.data ?? ProcessingState.idle;
                    final loading = proc == ProcessingState.loading || proc == ProcessingState.buffering;
                    if (loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.spotifyGreen),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                _SeekBarSection(
                  player: _player,
                  isDragging: _sliderDragging,
                  dragValue: _sliderDragValue,
                  onDragStart: (v) => setState(() {
                    _sliderDragging = true;
                    _sliderDragValue = v;
                  }),
                  onDragUpdate: (v) => setState(() => _sliderDragValue = v),
                  onDragEnd: (v) async {
                    await _player.seek(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _sliderDragging = false);
                  },
                  format: _fmtDuration,
                ),
                const SizedBox(height: 8),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundSecondaryButton(
                          icon: Icons.replay_10_rounded,
                          onPressed: () => _skipSeconds(-10),
                          tooltip: 'Back 10s',
                        ),
                        const SizedBox(width: 20),
                        _MainPlayButton(
                          playing: playing,
                          onTap: playing ? _player.pause : _player.play,
                        ),
                        const SizedBox(width: 20),
                        _RoundSecondaryButton(
                          icon: Icons.forward_10_rounded,
                          onPressed: () => _skipSeconds(10),
                          tooltip: 'Forward 10s',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _FreeAudioBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgHighlight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.spotifyGreen.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Free: short break with ad after ~1 min, then about every 3 min. Premium removes ads.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArtCard extends StatelessWidget {
  const _AlbumArtCard({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 32,
            offset: const Offset(0, 18),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: AppColors.spotifyGreen.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bgCard,
                    AppColors.bgElevated,
                    AppColors.bgHighlight,
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.5),
                    radius: 1.15,
                    colors: [
                      AppColors.spotifyGreen.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.graphic_eq_rounded,
                size: size * 0.38,
                color: AppColors.spotifyGreen.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainPlayButton extends StatelessWidget {
  const _MainPlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.spotifyGreen,
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: AppColors.spotifyGreen.withValues(alpha: 0.45),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 44,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _RoundSecondaryButton extends StatelessWidget {
  const _RoundSecondaryButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.bgHighlight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.textPrimary, size: 28),
          ),
        ),
      ),
    );
  }
}

class _SeekBarSection extends StatelessWidget {
  const _SeekBarSection({
    required this.player,
    required this.isDragging,
    required this.dragValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.format,
  });

  final AudioPlayer player;
  final bool isDragging;
  final double dragValue;
  final void Function(double) onDragStart;
  final void Function(double) onDragUpdate;
  final void Function(double) onDragEnd;
  final String Function(Duration) format;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final duration = durSnap.data ?? Duration.zero;
        final maxMs = duration.inMilliseconds.clamp(1, 1 << 30).toDouble();

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final posMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
            final double value =
                (isDragging ? dragValue.clamp(0.0, maxMs) : posMs).toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        format(Duration(milliseconds: value.round())),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        format(duration),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.spotifyGreen,
                    inactiveTrackColor: AppColors.bgHighlight,
                    thumbColor: AppColors.textPrimary,
                    overlayColor: AppColors.spotifyGreen.withValues(alpha: 0.18),
                  ),
                  child: Slider(
                    value: value.clamp(0, maxMs),
                    max: maxMs,
                    onChangeStart: (v) => onDragStart(v),
                    onChanged: (v) => onDragUpdate(v),
                    onChangeEnd: (v) => onDragEnd(v),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
