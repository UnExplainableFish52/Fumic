import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const shortName = 'Fumic';
  const fullTitle = 'Fumic - Magical Media Player';

  test('launcher surfaces use the short app name', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    final macosAppInfo = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final webManifest = File('web/manifest.json').readAsStringSync();
    final installer = File(
      'installer/windows/fumic-inno.iss',
    ).readAsStringSync();

    expect(androidManifest, contains('android:label="$shortName"'));
    expect(iosInfo, contains('<key>CFBundleDisplayName</key>'));
    expect(iosInfo, contains('<string>$shortName</string>'));
    expect(macosAppInfo, contains('PRODUCT_NAME = $shortName'));
    expect(webManifest, contains('"short_name": "$shortName"'));
    expect(installer, contains('#define MyAppName "$shortName"'));
    expect(installer, contains('Name: "{group}\\{#MyAppName}"'));
  });

  test('product metadata keeps the full app title', () {
    final windowsMain = File('windows/runner/main.cpp').readAsStringSync();
    final windowsResources = File(
      'windows/runner/Runner.rc',
    ).readAsStringSync();
    final webIndex = File('web/index.html').readAsStringSync();
    final installer = File(
      'installer/windows/fumic-inno.iss',
    ).readAsStringSync();

    expect(windowsMain, contains('window.Create(L"$fullTitle"'));
    expect(windowsResources, contains('VALUE "FileDescription", "$fullTitle"'));
    expect(windowsResources, contains('VALUE "ProductName", "$fullTitle"'));
    expect(webIndex, contains('<title>$fullTitle</title>'));
    expect(installer, contains('#define MyAppFullName "$fullTitle"'));
    expect(installer, contains('AppName={#MyAppFullName}'));
    expect(installer, contains('UninstallDisplayName={#MyAppFullName}'));
  });
}
