import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_students_app/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MedStudyApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
