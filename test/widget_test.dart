import 'package:flutter_test/flutter_test.dart';
import 'package:location_tracker/app.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('위치를 가져오는 중...'), findsOneWidget);
  });
}
