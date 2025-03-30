import 'package:flutter_test/flutter_test.dart';

// Direct import since we don't have a package name
import '../lib/main.dart';

void main() {
  testWidgets('Example app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app shows the title in the app bar
    expect(find.text('Firebase Messaging DevTool Demo'), findsOneWidget);

    // Verify that the token information is displayed (initially shows loading)
    expect(find.text('Your FCM Token:'), findsOneWidget);
    expect(find.text('Loading token...'), findsOneWidget);
  });
}
