import 'dart:io';

import 'package:logging/logging.dart';

import 'environment.dart';
import 'error.dart';
import 'go_builder.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';

final _log = Logger('build_pod');

Future<void> buildPod({required String rootDir}) async {
  final config = BuildConfig.load(rootDir: rootDir);
  final builder = GoBuilder(rootDir: rootDir, config: config);

  final platformName = Platform.environment['CARGOKIT_DARWIN_PLATFORM_NAME'];
  if (platformName == null || platformName.isEmpty) {
    throw BuildException('Missing CARGOKIT_DARWIN_PLATFORM_NAME');
  }

  final goos = platformName == 'macosx' ? 'darwin' : platformName;

  // Build for host architecture only
  final goarch = await Environment.hostArch;
  final targets = Target.forPlatform(
    goos,
  ).where((t) => t.goarch == goarch).toList();
  if (targets.isEmpty) {
    throw BuildException('No target found for $goos/$goarch');
  }

  _log.info(kDoubleSeparator);
  _log.info('Build Pod: $goos/$goarch');
  _log.info(kSeparator);
  await builder.build(targets.first);
}
