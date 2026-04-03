import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/topics_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart' show AppColors, buildMedStudyTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.medicalstudents.medical_students_app.audio',
    androidNotificationChannelName: 'Medical Audios',
    androidNotificationOngoing: true,
  );
  runApp(const MedicalAudiosApp());
}

class MedicalAudiosApp extends StatefulWidget {
  const MedicalAudiosApp({super.key});

  @override
  State<MedicalAudiosApp> createState() => _MedicalAudiosAppState();
}

class _MedicalAudiosAppState extends State<MedicalAudiosApp> {
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
        if (mounted) setState(() => _user = u);
      } catch (_) {
        await ApiClient.saveToken(null);
        if (mounted) setState(() => _user = null);
      }
    } else {
      if (mounted) setState(() => _user = null);
    }
    if (mounted) setState(() => _boot = false);
  }

  void _onAuthChanged() {
    _restore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Audios',
      theme: buildMedStudyTheme(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: _boot
          ? const Scaffold(
              backgroundColor: AppColors.bgBase,
              body: Center(child: CircularProgressIndicator()),
            )
          : TopicsScreen(
              api: _api,
              user: _user,
              onAuthChanged: _onAuthChanged,
            ),
    );
  }
}
