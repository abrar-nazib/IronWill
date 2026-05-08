import 'package:flutter_test/flutter_test.dart';
import 'package:lockedin/main.dart';
import 'package:lockedin/services/app_services.dart';

void main() {
  testWidgets('App boots without throwing', (tester) async {
    final services = AppServices.mock();
    await tester.pumpWidget(LockedInApp(services: services));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Today'), findsWidgets);
  });
}
