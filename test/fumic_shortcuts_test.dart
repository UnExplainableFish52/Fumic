import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/app/fumic_shortcuts.dart';
import 'package:fumic/src/models/fumic_page.dart';

Intent? _letter(
  Map<ShortcutActivator, Intent> shortcuts,
  LogicalKeyboardKey key,
) {
  for (final entry in shortcuts.entries) {
    final activator = entry.key;
    if (activator is SingleActivator &&
        activator.trigger == key &&
        !activator.control &&
        !activator.shift &&
        !activator.alt &&
        !activator.meta) {
      return entry.value;
    }
  }
  return null;
}

void main() {
  test(
    'player view, minimize, controls, and window fullscreen are separate shortcuts',
    () {
      for (final fullPlayer in [false, true]) {
        final shortcuts = fumicShortcuts(visualizerOpen: fullPlayer);
        for (final key in [LogicalKeyboardKey.keyF, LogicalKeyboardKey.keyE]) {
          expect(_letter(shortcuts, key), isA<ToggleFullPlayerIntent>());
        }
        expect(
          _letter(shortcuts, LogicalKeyboardKey.keyI),
          isA<MinimizeAppIntent>(),
        );
        expect(
          _letter(shortcuts, LogicalKeyboardKey.keyB),
          isA<TogglePlayerControlsIntent>(),
        );
        expect(
          _letter(shortcuts, LogicalKeyboardKey.f11),
          isA<ToggleFullscreenIntent>(),
        );
      }
      for (final shortcuts in [
        fumicShortcuts(searchFocused: true),
        fumicShortcuts(textInputFocused: true),
      ]) {
        for (final key in [
          LogicalKeyboardKey.keyF,
          LogicalKeyboardKey.keyE,
          LogicalKeyboardKey.keyI,
          LogicalKeyboardKey.keyB,
        ]) {
          expect(_letter(shortcuts, key), isNull);
        }
        expect(
          _letter(shortcuts, LogicalKeyboardKey.f11),
          isA<ToggleFullscreenIntent>(),
        );
      }
    },
  );

  test('JKL playback works on every page and in the full player', () {
    for (final page in FumicPage.values) {
      for (final visualizer in [true, false]) {
        final shortcuts = fumicShortcuts(
          page: page,
          visualizerOpen: visualizer,
        );
        final controlB = shortcuts.entries
            .where(
              (entry) =>
                  entry.key is SingleActivator &&
                  (entry.key as SingleActivator).trigger ==
                      LogicalKeyboardKey.keyB &&
                  (entry.key as SingleActivator).control &&
                  !(entry.key as SingleActivator).shift,
            )
            .toList();
        expect(controlB, hasLength(1));
        expect(
          controlB.single.value,
          visualizer
              ? isA<TogglePlayerControlsIntent>()
              : isA<AddSelectedToPlaylistIntent>(),
        );
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyB,
            control: true,
            shift: true,
          )],
          isA<AddSelectedToPlaylistIntent>(),
        );
        expect(
          (_letter(shortcuts, LogicalKeyboardKey.keyJ) as SeekIntent).seconds,
          -5,
        );
        expect(
          _letter(shortcuts, LogicalKeyboardKey.keyK),
          isA<TogglePlayIntent>(),
        );
        expect(
          (_letter(shortcuts, LogicalKeyboardKey.keyL) as SeekIntent).seconds,
          5,
        );
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyL,
            shift: true,
          )],
          isA<LoopIntent>(),
        );
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyK,
            control: true,
          )],
          isA<FocusSearchIntent>(),
        );
        final k = shortcuts.keys.whereType<SingleActivator>().singleWhere(
          (key) => key.trigger == LogicalKeyboardKey.keyK && !key.control,
        );
        expect(k.includeRepeats, isFalse);
      }
    }
  });

  test('JKL remains text while search or an editor has focus', () {
    for (final shortcuts in [
      fumicShortcuts(searchFocused: true),
      fumicShortcuts(textInputFocused: true),
    ]) {
      for (final key in [
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyL,
      ]) {
        expect(_letter(shortcuts, key), isNull);
      }
    }
  });
}
