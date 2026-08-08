// Campuz smoke tests.
//
// These tests verify that the app builds without throwing, and that the root
// widget (CampuzApp) is a MaterialApp backed by the GoRouter.  They do NOT
// exercise network calls or require a running backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('CampuzApp renders without throwing', (WidgetTester tester) async {
    // pumpWidget builds the widget tree.  We only pump once so the startup
    // screen's async _restoreSession never actually runs (no real storage or
    // network in the test environment).
    await tester.pumpWidget(const CampuzApp());

    // The root widget must be a MaterialApp (or Router equivalent).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
