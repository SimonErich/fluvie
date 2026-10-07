import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  group('BlockKind', () {
    test('wire names round-trip through fromJson', () {
      for (final kind in BlockKind.values) {
        final spec = BlockSpec.defaults(kind);
        expect(BlockSpec.fromJson(spec.toJson())?.kind, kind, reason: kind.name);
      }
    });

    test('labels are short chip text', () {
      expect(BlockKind.row.label, 'row');
      expect(BlockKind.column.label, 'column');
      expect(BlockKind.grid.label, 'grid');
      expect(BlockKind.list.label, 'list');
      expect(BlockKind.split.label, 'split');
      expect(BlockKind.titleBody.label, 'title');
    });
  });

  group('BlockSpec.fromJson', () {
    test('a non-map reads as no block', () {
      expect(BlockSpec.fromJson(null), isNull);
      expect(BlockSpec.fromJson('row'), isNull);
      expect(BlockSpec.fromJson(7), isNull);
    });

    test('an unknown kind reads as no block', () {
      expect(BlockSpec.fromJson({'kind': 'hexagon'}), isNull);
      expect(BlockSpec.fromJson(<String, Object?>{}), isNull);
    });

    test('row params parse with defaults for absent keys', () {
      final spec = BlockSpec.fromJson({'kind': 'row'})!;
      expect(spec.kind, BlockKind.row);
      expect(spec.spacing, 0.04);
      expect(spec.mainAlign, BlockMainAlign.start);
      expect(spec.crossAlign, BlockCrossAlign.stretch);
      expect(spec.equalSize, isTrue);
    });

    test('row aligns and the equal-size toggle parse', () {
      final spec = BlockSpec.fromJson({
        'kind': 'row',
        'spacing': 0.1,
        'mainAlign': 'spaceBetween',
        'crossAlign': 'center',
        'equalSize': false,
      })!;
      expect(spec.spacing, 0.1);
      expect(spec.mainAlign, BlockMainAlign.spaceBetween);
      expect(spec.crossAlign, BlockCrossAlign.center);
      expect(spec.equalSize, isFalse);
    });

    test('an unknown align falls back to its default', () {
      final spec = BlockSpec.fromJson({
        'kind': 'column',
        'mainAlign': 'sideways',
        'crossAlign': 'sideways',
      })!;
      expect(spec.mainAlign, BlockMainAlign.start);
      expect(spec.crossAlign, BlockCrossAlign.stretch);
    });

    test('params clamp into sane ranges', () {
      expect(BlockSpec.fromJson({'kind': 'row', 'spacing': -1})!.spacing, 0);
      expect(BlockSpec.fromJson({'kind': 'row', 'spacing': 3})!.spacing, 0.5);
      expect(BlockSpec.fromJson({'kind': 'grid', 'columns': 0})!.columns, 1);
      expect(BlockSpec.fromJson({'kind': 'grid', 'columns': 2.6})!.columns, 3);
      expect(BlockSpec.fromJson({'kind': 'list', 'itemHeight': 0})!.itemHeight, 0.01);
      expect(BlockSpec.fromJson({'kind': 'split', 'ratio': 0})!.ratio, 0.05);
      expect(BlockSpec.fromJson({'kind': 'split', 'ratio': 1})!.ratio, 0.95);
      expect(BlockSpec.fromJson({'kind': 'titleBody', 'heightFraction': 1})!.heightFraction, 0.95);
    });
  });

  group('BlockSpec.toJson', () {
    test('each kind serializes only its own params', () {
      expect(BlockSpec.defaults(BlockKind.row).toJson(), {
        'kind': 'row',
        'spacing': 0.04,
        'mainAlign': 'start',
        'crossAlign': 'stretch',
        'equalSize': true,
      });
      expect(BlockSpec.defaults(BlockKind.column).toJson(), {
        'kind': 'column',
        'spacing': 0.04,
        'mainAlign': 'start',
        'crossAlign': 'stretch',
        'equalSize': true,
      });
      expect(BlockSpec.defaults(BlockKind.grid).toJson(), {
        'kind': 'grid',
        'columns': 2,
        'spacing': 0.04,
      });
      expect(BlockSpec.defaults(BlockKind.list).toJson(), {
        'kind': 'list',
        'itemHeight': 0.18,
        'spacing': 0.04,
      });
      expect(BlockSpec.defaults(BlockKind.split).toJson(), {
        'kind': 'split',
        'ratio': 0.5,
        'gutter': 0.04,
      });
      expect(BlockSpec.defaults(BlockKind.titleBody).toJson(), {
        'kind': 'titleBody',
        'heightFraction': 0.25,
        'spacing': 0.04,
      });
    });

    test('parsed params survive the round-trip', () {
      final json = {'kind': 'split', 'ratio': 0.7, 'gutter': 0.02};
      expect(BlockSpec.fromJson(json)!.toJson(), json);
    });
  });
}
