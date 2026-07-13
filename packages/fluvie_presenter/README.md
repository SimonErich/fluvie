# fluvie_presenter

Present a [Fluvie](https://github.com/SimonErich/fluvie) `Video` live. Same
scenes, same timing engine, but instead of rendering a video file, the
presenter plays your scenes as slides, driven by a real clock and stepped by
input like Keynote or reveal.js.

```dart
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() => runApp(FluvieSlides(video));
```

Every scene is a slide. Wrap content in a `Stop` to reveal it click by
click, drop a `SpeakerNotes` in for the panel only you see, press S for the
speaker window, O for the overview, B to blank the screen. The same `Video`
still renders as a file.

Start with the docs in [`documentation/`](documentation/README.md), or run
the deployable shell in [`apps/slides`](../../apps/slides) and click through
the bundled tutorial decks.
