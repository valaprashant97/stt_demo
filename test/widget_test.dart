import 'package:flutter_test/flutter_test.dart';
import 'package:stt_demo/main.dart';

void main() {
  testWidgets('Speech to Text app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SpeechToTextApp());

    // Verify that the AppBar title is displayed.
    expect(find.text('Speech to Text Demo'), findsOneWidget);
  });
}
