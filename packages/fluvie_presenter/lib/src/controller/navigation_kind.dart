/// How the current position was reached — the difference between playing an
/// entrance and landing on a held state.
enum NavigationKind {
  /// A forward advance: the new step's content reveals and plays its
  /// authored entrance from this moment.
  forward,

  /// A backward move or a jump: the target renders as its settled, held
  /// state with no reverse animation. Ambient loops keep running.
  instant,
}
