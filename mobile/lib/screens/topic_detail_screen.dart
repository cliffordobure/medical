import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfx/pdfx.dart';

import '../services/api_client.dart';
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
    } catch (_) {
      setState(() => _error = 'Topic not found.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final t = _topic!;
    final title = t['title'] as String? ?? '';
    final pdfUrl = t['pdfUrl'] as String?;
    final audioUrl = t['audioUrl'] as String?;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    try {
      final bytes = await widget.api.downloadBytes(url);
      final doc = PdfDocument.openData(bytes);
      final c = PdfControllerPinch(document: doc);
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
    } catch (_) {
      setState(() {
        _loading = false;
        _err = 'Could not load PDF.';
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) return Center(child: Text(_err!));
    final c = _controller!;
    return Column(
      children: [
        if (!widget.premium)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Free: short ad on pages 3, 6, 9… Premium removes ads.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
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

  @override
  void initState() {
    super.initState();
    final url = widget.audioUrl;
    if (url != null) {
      _player.setUrl(url);
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
      return const Center(child: Text('No audio for this topic.'));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.premium)
            const Text(
              'Free: ad after ~1 min, then every ~3 min. Premium removes ads.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    onPressed: playing ? _player.pause : _player.play,
                    icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                  ),
                ],
              );
            },
          ),
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
