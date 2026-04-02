import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incitrack/login.dart';

void main() {
  testWidgets('login landing page renders primary actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Incident Report System'), findsOneWidget);
    expect(find.text('Open Login'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
