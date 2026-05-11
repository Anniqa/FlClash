import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const _allTargets = <String, String>{
  'android': 'apk',
  'linux': 'deb,appimage,rpm',
  'macos': 'dmg',
  'windows': 'exe,zip',
};

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    );

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem; // linux, macos, windows
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;

  // Only allow current host platform or android
  if (platform != host && platform != 'android') {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: $host, android',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final targets = results['targets'] as String? ?? _allTargets[platform]!;
  final rootDir = Directory.current.path;

  final exitCode = await _package(platform, env, targets, rootDir);
  exit(exitCode);
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln('Platform: current host platform (default) or android');
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((p, t) => stderr.writeln('  $p: $t'));
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
) async {
  final distributorDir = p.join(
    rootDir,
    'plugins',
    'flutter_distributor',
    'packages',
    'flutter_distributor',
  );
  final activateResult = await Process.run('dart', [
    'pub',
    'global',
    'activate',
    '-s',
    'path',
    distributorDir,
  ]);
  if (activateResult.exitCode != 0) {
    stderr.write(activateResult.stderr);
    return activateResult.exitCode;
  }

  // Write env.json for Flutter --dart-define-from-file
  // The Dart app reads APP_ENV from here. On Windows, build_tool writes
  // core_sha256.json separately (CORE_SHA256 is computed during the build).
  await File(
    p.join(rootDir, 'env.json'),
  ).writeAsString(jsonEncode({'APP_ENV': env}));

  final flutterBuildArgs = ['dart-define-from-file=env.json'];
  if (platform == 'windows') {
    flutterBuildArgs.add('dart-define-from-file=core_sha256.json');
  }
  if (platform == 'android') {
    flutterBuildArgs.add('split-per-abi');
  }

  // Auto-detect host arch for artifact naming on desktop platforms
  final descriptionArgs = <String>[];
  if (platform != 'android') {
    String arch;
    if (Platform.isWindows) {
      final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
      arch = pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
    } else {
      final result = Process.runSync('uname', ['-m']);
      final machine = (result.stdout as String).trim();
      arch = machine == 'aarch64' ? 'arm64' : machine;
    }
    descriptionArgs.addAll(['--description', arch]);
  }

  final process = await Process.start('flutter_distributor', [
    'package',
    '--skip-clean',
    '--platform',
    platform,
    '--targets',
    targets,
    ...descriptionArgs,
    for (final arg in flutterBuildArgs) '--flutter-build-args=$arg',
  ], includeParentEnvironment: true);

  final stdoutDone = process.stdout.pipe(stdout);
  final stderrDone = process.stderr.pipe(stderr);
  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  return exitCode;
}
