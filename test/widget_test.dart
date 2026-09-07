import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:practice_recorder/main.dart';

void main() {
  testWidgets('App boots to home', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PracticeRecorderApp()),
    );
    await tester.pump();
    expect(find.textContaining('Practice'), findsOneWidget);
  });
}
