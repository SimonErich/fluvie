# fluvie_presenter

Present a [Fluvie](https://github.com/SimonErich/fluvie) `Video` live. Same
scenes, same timing engine, but instead of rendering a video file, the
presenter plays your scenes as slides, driven by a real clock and stepped by
input like Keynote or reveal.js.

```dart
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() => runApp(FluvieSlides(myVideo));
```

The package is under construction; the docs land in
[`documentation/`](documentation/) as the features do.
