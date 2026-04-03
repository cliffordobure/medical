import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/green_wave_header.dart';
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
  int _navIndex = 0;
  final _searchQuery = TextEditingController();

  List<dynamic> _topics = [];
  String? _error;
  bool _loading = true;
  _TopicFilter _filter = _TopicFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    super.dispose();
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
      setState(() => _error = ApiClient.connectionHint(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _shortName {
    final u = widget.user;
    if (u == null) return 'there';
    final email = u['email'] as String? ?? '';
    final part = email.split('@').first;
    if (part.isEmpty) return 'there';
    return part[0].toUpperCase() + part.substring(1);
  }

  Iterable<Map<String, dynamic>> get _filteredTopics {
    Iterable<Map<String, dynamic>> list =
        _topics.map((e) => Map<String, dynamic>.from(e as Map));
    switch (_filter) {
      case _TopicFilter.pdf:
        list = list.where((t) => t['hasPdf'] == true);
        break;
      case _TopicFilter.audio:
        list = list.where((t) => t['hasAudio'] == true);
        break;
      case _TopicFilter.all:
        break;
    }
    final q = _searchQuery.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((t) {
      final title = (t['title'] as String? ?? '').toLowerCase();
      final desc = (t['description'] as String? ?? '').toLowerCase();
      return title.contains(q) || desc.contains(q);
    });
  }

  Future<void> _openPremium() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(api: widget.api, onDone: widget.onAuthChanged),
      ),
    );
    widget.onAuthChanged();
  }

  Future<void> _openLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
    widget.onAuthChanged();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final premium = u != null && u['isPremium'] == true;
    final student = u != null && u['role'] == 'student';

    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeTab(context, premium, student),
          _buildSearchTab(context, premium),
          _buildProfileTab(context, premium, student),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, bool premium, bool student) {
    return RefreshIndicator(
      color: AppColors.spotifyGreen,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: GreenWaveHeader(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$_greeting,\n$_shortName',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        if (student && !premium)
                          Material(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              onTap: _openPremium,
                              borderRadius: BorderRadius.circular(24),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, color: Colors.black87, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Premium',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == _TopicFilter.all,
                      onTap: () => setState(() => _filter = _TopicFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'PDF',
                      selected: _filter == _TopicFilter.pdf,
                      onTap: () => setState(() => _filter = _TopicFilter.pdf),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Audio',
                      selected: _filter == _TopicFilter.audio,
                      onTap: () => setState(() => _filter = _TopicFilter.audio),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, height: 1.4)),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your topics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_filteredTopics.length} items',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _featuredRow(context, premium)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final list = _filteredTopics.toList();
                    if (i >= list.length) return null;
                    final t = list[i];
                    final slug = t['slug'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TopicTileCard(
                        title: t['title'] as String? ?? '',
                        description: t['description'] as String? ?? '',
                        hasPdf: t['hasPdf'] == true,
                        hasAudio: t['hasAudio'] == true,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicDetailScreen(
                                api: widget.api,
                                slug: slug,
                                premium: premium,
                                onPremiumChanged: widget.onAuthChanged,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: _filteredTopics.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featuredRow(BuildContext context, bool premium) {
    final featured = _filteredTopics.take(6).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            'Jump back in',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featured.length,
            itemBuilder: (context, i) {
              final t = featured[i];
              final slug = t['slug'] as String;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FeaturedCard(
                  title: t['title'] as String? ?? '',
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopicDetailScreen(
                          api: widget.api,
                          slug: slug,
                          premium: premium,
                          onPremiumChanged: widget.onAuthChanged,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(BuildContext context, bool premium) {
    final list = _filteredTopics.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
          child: TextField(
            controller: _searchQuery,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'What do you want to study?',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    final slug = t['slug'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TopicTileCard(
                        title: t['title'] as String? ?? '',
                        description: t['description'] as String? ?? '',
                        hasPdf: t['hasPdf'] == true,
                        hasAudio: t['hasAudio'] == true,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicDetailScreen(
                                api: widget.api,
                                slug: slug,
                                premium: premium,
                                onPremiumChanged: widget.onAuthChanged,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context, bool premium, bool student) {
    final u = widget.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        if (u == null) ...[
          const Text(
            'Sign in to save progress and unlock Premium.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openLogin,
              child: const Text('LOG IN'),
            ),
          ),
        ] else ...[
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.bgHighlight,
            child: Text(
              (u['email'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            u['email'] as String? ?? '',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (premium)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.spotifyGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: AppColors.spotifyGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (student && !premium) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openPremium,
                child: const Text('GET PREMIUM'),
              ),
            ),
          ],
          const SizedBox(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            title: const Text('Log out', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () async {
              await ApiClient.saveToken(null);
              widget.onAuthChanged();
            },
          ),
        ],
      ],
    );
  }
}

enum _TopicFilter { all, pdf, audio }

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.spotifyGreen : AppColors.bgHighlight,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.spotifyGreen.withValues(alpha: 0.35),
                        AppColors.bgHighlight,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicTileCard extends StatelessWidget {
  const _TopicTileCard({
    required this.title,
    required this.description,
    required this.hasPdf,
    required this.hasAudio,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool hasPdf;
  final bool hasAudio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.spotifyGreen.withValues(alpha: 0.4),
                      AppColors.bgHighlight,
                    ],
                  ),
                ),
                child: const Icon(Icons.topic_rounded, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.25),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hasPdf)
                          _tinyBadge('PDF'),
                        if (hasPdf && hasAudio) const SizedBox(width: 6),
                        if (hasAudio) _tinyBadge('AUDIO'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgHighlight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted),
      ),
    );
  }
}
