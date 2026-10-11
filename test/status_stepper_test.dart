import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/app_state/accessibility_provider.dart';
import 'package:my_senior_app/models/application_status.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:my_senior_app/widgets/status_stepper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpStepper(WidgetTester tester, ApplicationStage stage) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Preferences.load();
    final access = await tester.runAsync(() => AccessibilityProvider.load(prefs));

    // A small phone with the biggest text the app allows.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: access!,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: StatusStepper(stage: stage),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('needs action adds its own step and fits', (tester) async {
    await pumpStepper(tester, ApplicationStage.needsAction);
    expect(tester.takeException(), isNull);
    for (final label in ['Submitted', 'Under review', 'Action needed', 'Approved']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.priority_high), findsOneWidget);
  });

  testWidgets('a rejected application ends in "Not approved"', (tester) async {
    await pumpStepper(tester, ApplicationStage.rejected);
    expect(tester.takeException(), isNull);
    expect(find.text('Not approved'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('under review shows three steps', (tester) async {
    await pumpStepper(tester, ApplicationStage.review);
    expect(find.text('Action needed'), findsNothing);
    expect(find.text('Approved'), findsOneWidget);
  });
}
