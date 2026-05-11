import 'dart:io';

import 'package:logging/logging.dart';

import 'error.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'go_builder.dart';

final _log = Logger('build_cmake');

Future<void> buildCmake({required String rootDir}) async {
  final config = BuildConfig.load(rootDir: rootDir);
  final builder = GoBuilder(rootDir: rootDir, config: config);

  final targetPlatform =
      Platform.environment['CARGOKIT_TARGET_PLATFORM'] ?? _defaultPlatform();

  final parts = targetPlatform.split('-');
  if (parts.length < 2) {
    throw BuildException('Invalid target platform: $targetPlatform');
  }

  final flutterOs = parts[0]; // windows, linux
  final flutterArch = parts[1]; // x64, arm64

  final goos = flutterOs == 'windows' ? 'windows' : 'linux';
  final goarch = flutterArch == 'x64' ? 'amd64' : flutterArch;

  final targets = Target.forPlatform(goos).where((t) => t.goarch == goarch).toList();
  if (targets.isEmpty) {
    throw BuildException('No target found for $goos/$goarch');
  }

  _log.info(kDoubleSeparator);
  _log.info('Build CMake: $goos/$goarch');
  _log.info(kSeparator);
  await builder.build(targets.first);
}

String _defaultPlatform() {
  if (Platform.isWindows) return 'windows-x64';
  if (Platform.isLinux) return 'linux-x64';
  return 'linux-x64';
}
