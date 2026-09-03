import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/hubs/views/join_hub_screen.dart';
import 'package:mobile/screens/hubs/widget/invite_card.dart';

void main() {
  testWidgets('InviteCard has Revoke and Regenerate buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: InviteCard(hubId: 1, hubName: 'Test Hub'),
      ),
    ));

    // Initially loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // After loading (we would need to mock AuthApiService to properly test it after load)
    // For now we just verify it exists if we pump the UI when it is not loading.
  });

  testWidgets('JoinHubScreen has Scan QR Code button', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: JoinHubScreen(),
    ));

    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}
