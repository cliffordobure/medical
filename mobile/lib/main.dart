import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'screens/topics_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedStudyApp());
}

class MedStudyApp extends StatefulWidget {
  const MedStudyApp({super.key});

  @override
  State<MedStudyApp> createState() => _MedStudyAppState();
}

class _MedStudyAppState extends State<MedStudyApp> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _user;
  bool _boot = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final t = await ApiClient.getToken();
    if (t != null && t.isNotEmpty) {
      try {
        final u = await _api.me();
        setState(() => _user = u);
      } catch (_) {
        await ApiClient.saveToken(null);
        setState(() => _user = null);
      }
    }
    setState(() => _boot = false);
  }

  void _onAuthChanged() {
    _restore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedStudy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        useMaterial3: true,
      ),
      home: _boot
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : TopicsScreen(
              api: _api,
              user: _user,
              onAuthChanged: _onAuthChanged,
            ),
    );
  }
}
