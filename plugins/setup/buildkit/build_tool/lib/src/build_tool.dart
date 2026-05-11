import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'build_cmake.dart';
import 'build_gradle.dart';
import 'build_pod.dart';
import 'error.dart';
import 'go_builder.dart';
import 'logging.dart';
import 'options.dart';
import 'rust_builder.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('build_tool');

String _rootDir = '.';

String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        File(p.join(dir.path, 'core')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

abstract class BuildCommand extends Command {
  Future<void> runBuildCommand();

  @override
  Future<void> run() async {
    await runBuildCommand();
  }
}

class BuildAndroidCommand extends BuildCommand {
  BuildAndroidCommand() {
    argParser.addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      help: 'Target architecture (omit to build all)',
    );
  }

  @override
  final name = 'android';

  @override
  final description = 'Build Android Go core (c-shared library)';

  @override
  Future<void> runBuildCommand() async {
    final archName = argResults?['arch'] as String?;
    final config = BuildConfig.load(rootDir: _rootDir);

    final targets = Target.forPlatform('android')
        .where((t) => archName == null || t.goarch == archName)
        .toList();

    final builder = GoBuilder(rootDir: _rootDir, config: config);
    final corePaths = await builder.buildAll(targets);

    _log.info('Build complete: $corePaths');
  }
}

class BuildLinuxCommand extends BuildCommand {
  BuildLinuxCommand() {
    argParser.addOption(
      'arch',
      valueHelp: 'arm64,amd64',
      help: 'Target architecture',
    );
  }

  @override
  final name = 'linux';

  @override
  final description = 'Build Linux Go core (executable)';

  @override
  Future<void> runBuildCommand() async {
    final archName = argResults?['arch'] as String?;
    final config = BuildConfig.load(rootDir: _rootDir);

    final arch = archName ?? 'amd64';
    final targets = Target.forPlatform('linux')
        .where((t) => t.goarch == arch)
        .toList();

    if (targets.isEmpty) {
      throw BuildException('Invalid arch: $archName. Must be arm64 or amd64');
    }

    final builder = GoBuilder(rootDir: _rootDir, config: config);
    final corePaths = await builder.buildAll(targets);

    _log.info('Build complete: $corePaths');
  }
}

class BuildWindowsCommand extends BuildCommand {
  BuildWindowsCommand() {
    argParser.addOption(
      'arch',
      valueHelp: 'amd64,arm64',
      help: 'Target architecture',
    );
  }

  @override
  final name = 'windows';

  @override
  final description = 'Build Windows Go core + Rust helper';

  @override
  Future<void> runBuildCommand() async {
    final archName = argResults?['arch'] as String?;
    final config = BuildConfig.load(rootDir: _rootDir);

    final arch = archName ?? 'amd64';
    final targets = Target.forPlatform('windows')
        .where((t) => t.goarch == arch)
        .toList();

    if (targets.isEmpty) {
      throw BuildException('Invalid arch: $archName');
    }

    final goBuilder = GoBuilder(rootDir: _rootDir, config: config);
    final corePaths = await goBuilder.buildAll(targets);

    final coreSha256 = await calcSha256(corePaths.first);

    final rustBuilder = RustBuilder(rootDir: _rootDir, config: config);
    await rustBuilder.build(targets.first, coreSha256);

    await File(p.join(_rootDir, 'core_sha256.json'))
        .writeAsString(jsonEncode({'CORE_SHA256': coreSha256}));
    _log.info('Build complete: $corePaths');
  }
}

class BuildMacosCommand extends BuildCommand {
  BuildMacosCommand() {
    argParser.addOption(
      'arch',
      valueHelp: 'arm64,amd64',
      help: 'Target architecture',
    );
  }

  @override
  final name = 'macos';

  @override
  final description = 'Build macOS Go core (executable)';

  @override
  Future<void> runBuildCommand() async {
    final archName = argResults?['arch'] as String?;
    final config = BuildConfig.load(rootDir: _rootDir);

    final arch = archName ?? 'arm64';
    final targets = Target.forPlatform('darwin')
        .where((t) => t.goarch == arch)
        .toList();

    if (targets.isEmpty) {
      throw BuildException('Invalid arch: $archName. Must be arm64 or amd64');
    }

    final builder = GoBuilder(rootDir: _rootDir, config: config);
    final corePaths = await builder.buildAll(targets);

    _log.info('Build complete: $corePaths');
  }
}

class BuildPodCommand extends BuildCommand {
  @override
  final name = 'pod';

  @override
  final description = 'Build Go core for iOS/macOS pod (auto-invoked by CocoaPods)';

  @override
  Future<void> runBuildCommand() async {
    await buildPod(rootDir: _rootDir);
  }
}

class BuildGradleCommand extends BuildCommand {
  @override
  final name = 'gradle';

  @override
  final description = 'Build Go core for Android (auto-invoked by Gradle)';

  @override
  Future<void> runBuildCommand() async {
    await buildGradle(rootDir: _rootDir);
  }
}

class BuildCmakeCommand extends BuildCommand {
  @override
  final name = 'cmake';

  @override
  final description = 'Build Go core for Linux/Windows (auto-invoked by CMake)';

  @override
  Future<void> runBuildCommand() async {
    await buildCmake(rootDir: _rootDir);
  }
}

Future<void> runMain(List<String> args) async {
  try {
    initLogging();

    final runner = CommandRunner('build_tool', 'FlClash build tool')
      ..argParser.addOption(
        'root-dir',
        valueHelp: '<path>',
        help: 'Project root directory (default: auto-detect)',
      )
      ..addCommand(BuildAndroidCommand())
      ..addCommand(BuildLinuxCommand())
      ..addCommand(BuildWindowsCommand())
      ..addCommand(BuildMacosCommand())
      ..addCommand(BuildPodCommand())
      ..addCommand(BuildGradleCommand())
      ..addCommand(BuildCmakeCommand());

    final topResults = runner.parse(args);
    _rootDir = (topResults['root-dir'] as String?) ?? _findProjectRoot();
    await runner.run(args);
  } on BuildException catch (e) {
    _log.severe(e.toString());
    exit(1);
  } on CommandFailedException catch (e) {
    _log.severe(e.toString());
    exit(1);
  } on UsageException catch (e) {
    stderr.writeln(e.toString());
    exit(1);
  } catch (e, s) {
    _log.severe(kDoubleSeparator);
    _log.severe('Build failed with unexpected error:');
    _log.severe(kSeparator);
    _log.severe('$e');
    _log.severe(kSeparator);
    _log.severe('$s');
    _log.severe(kDoubleSeparator);
    exit(1);
  }
}
