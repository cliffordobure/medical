import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'login_screen.dart';
import 'subscribe_screen.dart';
import 'topic_detail_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({
    super.key,
    required this.api,
    required this.onAuthChanged,
    this.user,
  });

  final ApiClient api;
  final Map<String, dynamic>? user;
  final VoidCallback onAuthChanged;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  List<dynamic> _topics = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.fetchTopics();
      setState(() => _topics = list);
    } catch (e) {
      setState(() => _error = 'Could not load topics. Check API_BASE and server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final premium = u != null && u['isPremium'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedStudy'),
        actions: [
          if (u == null)
            TextButton(
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
                );
                widget.onAuthChanged();
              },
              child: const Text('Log in'),
            )
          else ...[
            if (u['role'] == 'student' && !premium)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubscribeScreen(
                        api: widget.api,
                        onDone: widget.onAuthChanged,
                      ),
                    ),
                  );
                  widget.onAuthChanged();
                },
                child: const Text('Premium'),
              ),
            IconButton(
              onPressed: () async {
                await ApiClient.saveToken(null);
                widget.onAuthChanged();
              },
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _topics.length,
                    itemBuilder: (context, i) {
                      final t = _topics[i] as Map<String, dynamic>;
                      final slug = t['slug'] as String;
                      return Card(
                        child: ListTile(
                          title: Text(t['title'] as String? ?? ''),
                          subtitle: Text(
                            t['description'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TopicDetailScreen(
                                  api: widget.api,
                                  slug: slug,
                                  premium: premium,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
