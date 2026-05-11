import 'dart:io';

import 'package:logging/logging.dart';

import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'go_builder.dart';

final _log = Logger('build_gradle');

Future<void> buildGradle({required String rootDir}) async {
  final config = BuildConfig.load(rootDir: rootDir);
  final builder = GoBuilder(rootDir: rootDir, config: config);

  final targetPlatformsStr =
      Platform.environment['CARGOKIT_TARGET_PLATFORMS'] ?? 'android-arm,android-arm64,android-x64';
  final platforms = targetPlatformsStr.split(',');

  for (final flutterPlatform in platforms) {
    final matches = Target.all.where((t) => t.flutterPlatform == flutterPlatform).toList();
    if (matches.isEmpty) {
      _log.warning('Unknown flutter platform: $flutterPlatform, skipping');
      continue;
    }

    _log.info(kDoubleSeparator);
    _log.info('Build Gradle: ${matches.first}');
    _log.info(kSeparator);
    await builder.build(matches.first);
  }
}
