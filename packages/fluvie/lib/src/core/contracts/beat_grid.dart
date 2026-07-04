/// The analysed beat positions of one audio track, queried in frames.
///
/// `Trigger.beat` resolves against this contract: the resolver asks for the
/// first qualifying beat at or after the element's window start and snaps the
/// animation to it. The real grid comes from beat detection at render; the
/// timing engine is developed and tested against a fake.
///
/// A grid is immutable, pre-computed data — querying it is pure, which keeps
/// timing resolution deterministic.
///
/// Beat positions are expressed in **absolute video frames**: the resolver
/// queries with the element window's absolute start frame, so the detection
/// service must emit its grid in the same frame space.
// ignore: one_member_abstracts — the contract is the type; a fake in tests, detection at render.
abstract interface class BeatGrid {
  /// The frame of the first qualifying beat at or after [frame], or `null`
  /// when no qualifying beat remains.
  ///
  /// [every] keeps only every n-th beat of the grid, counted from the first
  /// beat (`every: 2` keeps beats 1, 3, 5, … of the track). It must be `>= 1`;
  /// the default keeps every beat.
  int? firstBeatAtOrAfter(int frame, {int every = 1});
}
