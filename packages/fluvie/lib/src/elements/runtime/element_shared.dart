import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';

/// Wraps [child] in a [SharedElement] when [anchor] is non-null, the one idiom
/// every element with a `shared:` parameter shares.
///
/// A `null` [anchor] returns [child] unchanged, so no [SharedElement] is mounted
/// (the null branch lives here rather than relying on `SharedElement`'s own
/// passthrough, to keep the wrap behavior-preserving). A non-null [anchor] ties
/// [child] to the same anchor in an adjacent scene for a hero morph across the
/// boundary.
///
/// This is the single place in the elements layer that imports
/// `composition/transition/shared_element.dart`; every element delegates here.
Widget wrapShared(Anchor? anchor, Widget child) =>
    anchor == null ? child : SharedElement(anchor: anchor, child: child);
