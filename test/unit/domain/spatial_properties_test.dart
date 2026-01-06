import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/spatial_properties.dart';

void main() {
  group('SpatialProperties', () {
    test('creates with all null values by default', () {
      const props = SpatialProperties();

      expect(props.x, isNull);
      expect(props.y, isNull);
      expect(props.width, isNull);
      expect(props.height, isNull);
      expect(props.rotation, isNull);
      expect(props.scaleX, isNull);
      expect(props.scaleY, isNull);
      expect(props.opacity, isNull);
      expect(props.anchorX, isNull);
      expect(props.anchorY, isNull);
    });

    test('creates with specified values', () {
      const props = SpatialProperties(
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        rotation: 45,
        scaleX: 1.5,
        scaleY: 2.0,
        opacity: 0.8,
        anchorX: 0.5,
        anchorY: 0.5,
      );

      expect(props.x, 100);
      expect(props.y, 200);
      expect(props.width, 400);
      expect(props.height, 300);
      expect(props.rotation, 45);
      expect(props.scaleX, 1.5);
      expect(props.scaleY, 2.0);
      expect(props.opacity, 0.8);
      expect(props.anchorX, 0.5);
      expect(props.anchorY, 0.5);
    });

    group('identity constructor', () {
      test('creates with default transform values', () {
        const props = SpatialProperties.identity();

        expect(props.x, 0);
        expect(props.y, 0);
        expect(props.width, isNull);
        expect(props.height, isNull);
        expect(props.rotation, 0);
        expect(props.scaleX, 1.0);
        expect(props.scaleY, 1.0);
        expect(props.opacity, 1.0);
        expect(props.anchorX, 0.5);
        expect(props.anchorY, 0.5);
      });
    });

    group('centered constructor', () {
      test('creates centered properties with null position', () {
        const props = SpatialProperties.centered();

        expect(props.x, isNull);
        expect(props.y, isNull);
        expect(props.anchorX, 0.5);
        expect(props.anchorY, 0.5);
      });

      test('creates centered with size', () {
        const props = SpatialProperties.centered(
          width: 400,
          height: 300,
        );

        expect(props.width, 400);
        expect(props.height, 300);
        expect(props.x, isNull);
        expect(props.y, isNull);
      });

      test('creates centered with transforms', () {
        const props = SpatialProperties.centered(
          rotation: 45,
          scaleX: 1.5,
          scaleY: 1.5,
          opacity: 0.5,
        );

        expect(props.rotation, 45);
        expect(props.scaleX, 1.5);
        expect(props.scaleY, 1.5);
        expect(props.opacity, 0.5);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const original = SpatialProperties(
          x: 100,
          y: 200,
          width: 400,
          height: 300,
          opacity: 1.0,
        );

        final copied = original.copyWith(
          x: 150,
          opacity: 0.5,
        );

        expect(copied.x, 150);
        expect(copied.y, 200); // Unchanged
        expect(copied.width, 400); // Unchanged
        expect(copied.height, 300); // Unchanged
        expect(copied.opacity, 0.5);
      });

      test('preserves null values when not specified', () {
        const original = SpatialProperties(x: 100);

        final copied = original.copyWith(y: 200);

        expect(copied.x, 100);
        expect(copied.y, 200);
        expect(copied.width, isNull);
      });
    });

    group('toMap', () {
      test('excludes null values', () {
        const props = SpatialProperties(
          x: 100,
          y: 200,
          opacity: 0.5,
        );

        final map = props.toMap();

        expect(map['x'], 100);
        expect(map['y'], 200);
        expect(map['opacity'], 0.5);
        expect(map.containsKey('width'), isFalse);
        expect(map.containsKey('height'), isFalse);
        expect(map.containsKey('rotation'), isFalse);
      });

      test('includes all set values', () {
        const props = SpatialProperties(
          x: 10,
          y: 20,
          width: 100,
          height: 200,
          rotation: 45,
          scaleX: 1.5,
          scaleY: 2.0,
          opacity: 0.8,
          anchorX: 0.5,
          anchorY: 0.5,
        );

        final map = props.toMap();

        expect(map.length, 10);
        expect(map['x'], 10);
        expect(map['y'], 20);
        expect(map['width'], 100);
        expect(map['height'], 200);
        expect(map['rotation'], 45);
        expect(map['scaleX'], 1.5);
        expect(map['scaleY'], 2.0);
        expect(map['opacity'], 0.8);
        expect(map['anchorX'], 0.5);
        expect(map['anchorY'], 0.5);
      });

      test('returns empty map for default properties', () {
        const props = SpatialProperties();

        final map = props.toMap();

        expect(map.isEmpty, isTrue);
      });
    });

    group('fromMap', () {
      test('creates from map with all values', () {
        final map = {
          'x': 100.0,
          'y': 200.0,
          'width': 400.0,
          'height': 300.0,
          'rotation': 45.0,
          'scaleX': 1.5,
          'scaleY': 2.0,
          'opacity': 0.8,
          'anchorX': 0.5,
          'anchorY': 0.5,
        };

        final props = SpatialProperties.fromMap(map);

        expect(props.x, 100);
        expect(props.y, 200);
        expect(props.width, 400);
        expect(props.height, 300);
        expect(props.rotation, 45);
        expect(props.scaleX, 1.5);
        expect(props.scaleY, 2.0);
        expect(props.opacity, 0.8);
        expect(props.anchorX, 0.5);
        expect(props.anchorY, 0.5);
      });

      test('handles missing values', () {
        final map = {
          'x': 100.0,
          'opacity': 0.5,
        };

        final props = SpatialProperties.fromMap(map);

        expect(props.x, 100);
        expect(props.y, isNull);
        expect(props.opacity, 0.5);
        expect(props.width, isNull);
      });

      test('handles empty map', () {
        final props = SpatialProperties.fromMap({});

        expect(props.x, isNull);
        expect(props.y, isNull);
        expect(props.width, isNull);
      });

      test('converts int to double', () {
        final map = {
          'x': 100, // int, not double
          'y': 200, // int, not double
        };

        final props = SpatialProperties.fromMap(map);

        expect(props.x, 100.0);
        expect(props.y, 200.0);
      });
    });

    group('equality', () {
      test('equal when all properties match', () {
        const props1 = SpatialProperties(
          x: 100,
          y: 200,
          opacity: 0.5,
        );

        const props2 = SpatialProperties(
          x: 100,
          y: 200,
          opacity: 0.5,
        );

        expect(props1 == props2, isTrue);
        expect(props1.hashCode, props2.hashCode);
      });

      test('not equal when properties differ', () {
        const props1 = SpatialProperties(x: 100, y: 200);
        const props2 = SpatialProperties(x: 100, y: 201);

        expect(props1 == props2, isFalse);
      });

      test('identical objects are equal', () {
        const props = SpatialProperties(x: 100);

        expect(props == props, isTrue);
      });

      test('default properties are equal', () {
        const props1 = SpatialProperties();
        const props2 = SpatialProperties();

        expect(props1 == props2, isTrue);
      });
    });

    group('serialization', () {
      test('roundtrip with all values', () {
        const original = SpatialProperties(
          x: 150.5,
          y: 250.5,
          width: 400,
          height: 300,
          rotation: 90,
          scaleX: 2.0,
          scaleY: 1.5,
          opacity: 0.75,
          anchorX: 0.25,
          anchorY: 0.75,
        );

        final json = original.toJson();
        final restored = SpatialProperties.fromJson(json);

        expect(restored, original);
      });

      test('roundtrip with null values', () {
        const original = SpatialProperties(
          x: 100,
          opacity: 0.5,
        );

        final json = original.toJson();
        final restored = SpatialProperties.fromJson(json);

        expect(restored.x, 100);
        expect(restored.opacity, 0.5);
        expect(restored.y, isNull);
        expect(restored.width, isNull);
      });

      test('roundtrip with identity', () {
        const original = SpatialProperties.identity();

        final json = original.toJson();
        final restored = SpatialProperties.fromJson(json);

        expect(restored.x, 0);
        expect(restored.y, 0);
        expect(restored.rotation, 0);
        expect(restored.scaleX, 1.0);
        expect(restored.scaleY, 1.0);
        expect(restored.opacity, 1.0);
      });
    });

    group('edge cases', () {
      test('negative values', () {
        const props = SpatialProperties(
          x: -100,
          y: -200,
          rotation: -45,
        );

        expect(props.x, -100);
        expect(props.y, -200);
        expect(props.rotation, -45);
      });

      test('zero values', () {
        const props = SpatialProperties(
          x: 0,
          y: 0,
          width: 0,
          height: 0,
          rotation: 0,
          scaleX: 0,
          scaleY: 0,
          opacity: 0,
        );

        expect(props.x, 0);
        expect(props.y, 0);
        expect(props.width, 0);
        expect(props.height, 0);
        expect(props.rotation, 0);
        expect(props.scaleX, 0);
        expect(props.scaleY, 0);
        expect(props.opacity, 0);
      });

      test('large values', () {
        const props = SpatialProperties(
          x: 10000,
          y: 10000,
          width: 7680,
          height: 4320,
          rotation: 360,
        );

        expect(props.x, 10000);
        expect(props.y, 10000);
        expect(props.width, 7680);
        expect(props.height, 4320);
        expect(props.rotation, 360);
      });

      test('anchor at corners', () {
        const topLeft = SpatialProperties(anchorX: 0, anchorY: 0);
        const topRight = SpatialProperties(anchorX: 1, anchorY: 0);
        const bottomLeft = SpatialProperties(anchorX: 0, anchorY: 1);
        const bottomRight = SpatialProperties(anchorX: 1, anchorY: 1);

        expect(topLeft.anchorX, 0);
        expect(topLeft.anchorY, 0);
        expect(topRight.anchorX, 1);
        expect(topRight.anchorY, 0);
        expect(bottomLeft.anchorX, 0);
        expect(bottomLeft.anchorY, 1);
        expect(bottomRight.anchorX, 1);
        expect(bottomRight.anchorY, 1);
      });

      test('fractional positions', () {
        const props = SpatialProperties(
          x: 100.123456,
          y: 200.654321,
        );

        expect(props.x, closeTo(100.123456, 0.000001));
        expect(props.y, closeTo(200.654321, 0.000001));
      });
    });
  });
}
