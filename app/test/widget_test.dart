import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitquest/main.dart';

void main() {
  testWidgets('App boots to splash branding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitQuestApp()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FitQuest'), findsOneWidget);
  });
}
