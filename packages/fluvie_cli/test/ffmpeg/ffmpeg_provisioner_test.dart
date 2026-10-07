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

final class _BoundedDownloader implements BoundedFfmpegDownloader {
  _BoundedDownloader(this.bytes);
  final List<int> bytes;
  final limits = <int>[];

  @override
  Future<List<int>> download(String url) => throw StateError('Expected a bounded download.');

  @override
  Future<List<int>> downloadBounded(String url, {required int maxBytes}) async {
    limits.add(maxBytes);
    return bytes;
  }
}

final _payload = Uint8List.fromList(List<int>.generate(4096, (i) => (i * 31) % 256));

const _innerPath = 'build/bin/ffmpeg';

List<int> _tarXz(List<int> bytes) => XZEncoder().encode(
  TarEncoder().encode(
    Archive()
      ..add(ArchiveFile(_innerPath, bytes.length, bytes))
      ..add(ArchiveFile('build/bin/ffprobe', bytes.length, bytes)),
  ),
);

FfmpegAsset _assetFor(List<int> archiveBytes, {int? sizeBytes, String? sha256Hex}) => FfmpegAsset(
  url: 'https://github.com/fixture/ffmpeg.tar.xz',
  format: FfmpegArchiveFormat.tarXz,
  archiveBinaryPath: _innerPath,
  archiveProbePath: 'build/bin/ffprobe',
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
    test('bounds both archive downloads to their exact trusted sizes', () async {
      final archive = _tarXz(_payload);
      final downloader = _BoundedDownloader(archive);
      final pinned = _assetFor(archive);
      final asset = FfmpegAsset(
        url: pinned.url,
        format: pinned.format,
        archiveBinaryPath: pinned.archiveBinaryPath,
        sha256: pinned.sha256,
        sizeBytes: pinned.sizeBytes,
        probeAsset: pinned,
      );
      final path = await FfmpegProvisioner(
        runner: runner,
        downloader: downloader,
        cache: cache,
      ).install(asset: asset);
      expect(downloader.limits, [archive.length, archive.length]);
      expect(File(path).readAsBytesSync(), _payload);
      expect(File(cache.probePath!).readAsBytesSync(), _payload);
    });

    test('downloads, extracts, chmods, probes, and installs the binary', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final logs = <String>[];

      final path = await provisioner(downloader).install(asset: _assetFor(archive), log: logs.add);

      expect(path, cache.binaryPath);
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), equals(_payload));
      verify(() => runner.run('chmod', any())).called(2);
      expect(File(cache.probePath!).readAsBytesSync(), equals(_payload));
      verify(() => runner.run(any(), const ['-version'])).called(2);
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
        () => runner.run(any(), const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 127, stdout: '', stderr: ''));

      await expectLater(
        () => provisioner(downloader).install(asset: _assetFor(archive)),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('did not run'))),
      );
      expect(File(cache.binaryPath!).existsSync(), isFalse);
    });

    test('concurrent installers share one complete installation', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final first = provisioner(downloader);
      final second = provisioner(downloader);
      final paths = await Future.wait([
        first.install(asset: _assetFor(archive)),
        second.install(asset: _assetFor(archive)),
      ]);
      expect(paths, [cache.binaryPath, cache.binaryPath]);
      expect(downloader.calls, 1);
      expect(File(cache.probePath!).existsSync(), isTrue);
    });

    test('failed forced update retains the previous complete pair', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final installer = provisioner(downloader);
      await installer.install(asset: _assetFor(archive));
      when(() => runner.run(any(), const ['-version'])).thenAnswer(
        (_) async => const ProcessRunResult(exitCode: 1, stdout: '', stderr: 'broken'),
      );
      await expectLater(
        installer.install(asset: _assetFor(archive), force: true),
        throwsA(isA<CliFailure>()),
      );
      expect(File(cache.binaryPath!).readAsBytesSync(), _payload);
      expect(File(cache.probePath!).readAsBytesSync(), _payload);
    });

    test('repairs a corrupt cached binary instead of reusing it', () async {
      final archive = _tarXz(_payload);
      final downloader = _FakeDownloader(archive);
      final installer = provisioner(downloader);
      await installer.install(asset: _assetFor(archive));
      when(() => runner.run(cache.binaryPath!, const ['-version'])).thenAnswer(
        (_) async => const ProcessRunResult(exitCode: 1, stdout: '', stderr: 'broken'),
      );
      await installer.install(asset: _assetFor(archive));
      expect(downloader.calls, 2);
      expect(File(cache.probePath!).existsSync(), isTrue);
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
