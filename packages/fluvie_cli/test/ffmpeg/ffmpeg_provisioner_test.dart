import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_downloader.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRunner extends Mock implements ProcessRunner {}

/// A downloader that hands back fixed bytes and counts its calls.
final class _FakeDownloader implements FfmpegDownloader {
  _FakeDownloader(this.bytes);
  final List<int> bytes;
  int calls = 0;

  @override
  Future<List<int>> download(String url) async {
    calls++;
    return bytes;
  }
}

final _payload = Uint8List.fromList(List<int>.generate(4096, (i) => (i * 31) % 256));

const _innerPath = 'build/bin/ffmpeg';

List<int> _tarXz(List<int> bytes) => XZEncoder().encode(
  TarEncoder().encode(Archive()..add(ArchiveFile(_innerPath, bytes.length, bytes))),
);

FfmpegAsset _assetFor(List<int> archiveBytes, {int? sizeBytes, String? sha256Hex}) => FfmpegAsset(
  url: 'https://github.com/fixture/ffmpeg.tar.xz',
  format: FfmpegArchiveFormat.tarXz,
  archiveBinaryPath: _innerPath,
  sha256: sha256Hex ?? sha256.convert(archiveBytes).toString(),
  sizeBytes: sizeBytes ?? archiveBytes.length,
);

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  late Directory tmpRoot;
  late _MockRunner runner;
  late FfmpegCache cache;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('fluvie_ffmpeg_prov_');
    runner = _MockRunner();
    when(
      () => runner.run(any(), any()),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''));
    cache = FfmpegCache(abi: Abi.linuxX64, environment: {'XDG_CACHE_HOME': tmpRoot.path});
  });

  tearDown(() {
    if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
  });

  FfmpegProvisioner provisioner(_FakeDownloader downloader) =>
      FfmpegProvisioner(runner: runner, downloader: downloader, cache: cache);

  group('install', () {
    test('downloads, extracts, chmods, probes, and installs the binary', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final logs = <String>[];

      final path = await provisioner(downloader).install(asset: _assetFor(archive), log: logs.add);

      expect(path, cache.binaryPath);
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), equals(_payload));
      verify(() => runner.run('chmod', ['+x', '$path.tmp'])).called(1);
      verify(() => runner.run(path, const ['-version'])).called(1);
      expect(File('$path.tmp').existsSync(), isFalse);
      expect(logs, isNotEmpty);
      expect(downloader.calls, 1);
    });

    test('is idempotent: a present install is not re-downloaded', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final prov = provisioner(downloader);
      await prov.install(asset: _assetFor(archive));

      final again = await prov.install();

      expect(again, cache.binaryPath);
      expect(downloader.calls, 1);
      expect(prov.isInstalled, isTrue);
    });

    test('force re-downloads over an existing install', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final prov = provisioner(downloader);
      await prov.install(asset: _assetFor(archive));

      await prov.install(asset: _assetFor(archive), force: true);

      expect(downloader.calls, 2);
      expect(File(cache.binaryPath!).existsSync(), isTrue);
    });

    test('rejects a checksum mismatch and installs nothing', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);

      await expectLater(
        () => provisioner(downloader).install(
          asset: _assetFor(archive, sha256Hex: 'd' * 64),
        ),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('SHA-256'))),
      );
      expect(File(cache.binaryPath!).existsSync(), isFalse);
    });

    test('rejects a size mismatch before hashing', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);

      await expectLater(
        () => provisioner(downloader).install(asset: _assetFor(archive, sizeBytes: 999999)),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('bytes'))),
      );
      expect(File(cache.binaryPath!).existsSync(), isFalse);
    });

    test('cleans up when chmod fails', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      when(
        () => runner.run('chmod', any()),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: '', stderr: 'denied'));

      await expectLater(
        () => provisioner(downloader).install(asset: _assetFor(archive)),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('executable'))),
      );
      expect(File(cache.binaryPath!).existsSync(), isFalse);
      expect(File('${cache.binaryPath}.tmp').existsSync(), isFalse);
    });

    test('removes the binary and fails when the probe does not run', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      when(
        () => runner.run(cache.binaryPath!, const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 127, stdout: '', stderr: ''));

      await expectLater(
        () => provisioner(downloader).install(asset: _assetFor(archive)),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('did not run'))),
      );
      expect(File(cache.binaryPath!).existsSync(), isFalse);
    });

    test('exposes the managed binary path and default wiring constructs', () {
      final downloader = _FakeDownloader(_tarXz(_payload));
      expect(provisioner(downloader).binaryPath, cache.binaryPath);
      expect(FfmpegProvisioner.new, returnsNormally);
    });

    test('fails clearly when no cache directory can be resolved', () async {
      final downloader = _FakeDownloader(_tarXz(_payload));
      final homeless = FfmpegProvisioner(
        runner: runner,
        downloader: downloader,
        cache: FfmpegCache(abi: Abi.linuxX64, environment: const <String, String>{}),
      );

      await expectLater(
        homeless.install,
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('cache directory')),
        ),
      );
      expect(downloader.calls, 0);
    });
  });
}
