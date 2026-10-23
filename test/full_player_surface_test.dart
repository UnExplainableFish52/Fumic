import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/widgets/full_player_surface.dart';

Widget _surface({
  VisualizerSettings settings = const VisualizerSettings(),
  Listenable? activity,
  bool active = true,
}) => MaterialApp(
  home: Scaffold(
    body: Focus(
      autofocus: true,
      child: TickerMode(
        enabled: active,
        child: FullPlayerSurface(
          settings: settings,
          activity: activity,
          content: const ColoredBox(color: Colors.black),
          controls: const SizedBox(
            height: 60,
            child: Center(child: Text('Controls')),
          ),
        ),
      ),
    ),
  ),
);

final _controls = find.byKey(const ValueKey('full-player-controls'));

void main() {
  testWidgets(
    'controls stay visible during a held touch and while a menu is open',
    (tester) async {
      await tester.pumpWidget(_surface());
      await tester.pumpAndSettle();
      final touch = await tester.startGesture(const Offset(40, 40));
      await tester.pump(const Duration(seconds: 20));
      expect(_controls, findsOneWidget);
      await touch.up();
      await tester.pump(const Duration(seconds: 3));
      final context = tester.element(find.byType(FullPlayerSurface));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(content: Text('Menu')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(_controls, findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'controls hide after inactivity and wake on keyboard and pointer activity',
    (tester) async {
      final activity = ValueNotifier(0);
      addTearDown(activity.dispose);
      await tester.pumpWidget(_surface(activity: activity));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(_controls, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_controls, findsNothing);
      activity.value++;
      await tester.pumpAndSettle();
      expect(_controls.hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(_controls, findsNothing);
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(_controls, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'manual hiding survives input and can be restored through settings',
    (tester) async {
      final activity = ValueNotifier(0);
      addTearDown(activity.dispose);
      await tester.pumpWidget(
        _surface(
          settings: const VisualizerSettings(showPlayerControls: false),
          activity: activity,
        ),
      );
      activity.value++;
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(seconds: 20));
      expect(_controls, findsNothing);
      await tester.pumpWidget(
        _surface(
          settings: const VisualizerSettings(playerControlsHideDelaySeconds: 0),
          activity: activity,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 2));
      expect(_controls, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'controls stay visible during hover and hide after the pointer leaves',
    (tester) async {
      await tester.pumpWidget(_surface());
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(_controls));
      await tester.pump(const Duration(seconds: 20));
      expect(_controls, findsOneWidget);
      await mouse.moveTo(const Offset(10, 10));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(_controls, findsNothing);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'custom delay is respected and background activity stops the timer',
    (tester) async {
      const settings = VisualizerSettings(playerControlsHideDelaySeconds: 3);
      await tester.pumpWidget(_surface(settings: settings));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(_surface(settings: settings, active: false));
      await tester.pump(const Duration(seconds: 20));
      expect(_controls, findsOneWidget);
      await tester.pumpWidget(_surface(settings: settings));
      await tester.pump(const Duration(seconds: 2));
      expect(_controls, findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_controls, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
