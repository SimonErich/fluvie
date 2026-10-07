# Native clip decoder fixtures

These tiny, generated H.264 files exercise actual on-device decoding. They have
no external source material and contain only four colored quadrants. The upper
left quadrant cycles red, green, blue, yellow, magenta, cyan; the other quadrants
are white (upper right), dark gray (lower left), and cyan (lower right).

- `fractional_rotated.mp4`: 12 frames at 30000/1001 fps, encoded as 64×32 pixels,
  with a 90-degree display matrix. Correct displayed dimensions are 32×64.
- `variable_rate.mp4`: six 64×32 frames at presentation timestamps
  `[0, 1001, 3003, 4004, 8008, 10010] / 30000` seconds.

Both contain B-frames (libx264, CRF 12, yuv420p, keyint 30, scenecut 0, b-adapt 0,
two B-frames). The JSON files record the independently FFmpeg-decoded RGB values
at the centers of all four quadrants for every presentation-order frame. Native
acceptance checks these with a color-conversion tolerance of 18 per channel.
This catches wrong source ordinals, rounded frame clocks, decode-order indexes,
channel swaps, vertical flips, and ignored display rotation. Neither file has
an audio track. The separate native media acceptance test covers AAC metadata,
source-audio re-import, trimmed speed ramps, fades, and output PCM.
