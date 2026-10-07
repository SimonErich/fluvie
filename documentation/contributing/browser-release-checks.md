# Browser release checks

`tool/verify_browser_matrix.sh` exercises the shipped media bridges and the
compiled Flutter application in Chrome, Firefox and Playwright's Linux WebKit.
The suite opens the main application, creates an empty editor, and opens the
speaker route. Media acceptance covers requested frame selection, bounded RGBA
retention, unsupported-container refusal, real H.264 output, embedded-audio
metadata, worker cancellation, cleanup and reload.

Linux WebKit is useful engine coverage; it does not replace Safari testing on
macOS or iOS. Reports identify each actual engine version and native frame
format. `FLUVIE_BROWSERS` may select `chrome`, `firefox`, or `webkit-linux`;
empty selections and misspelled names fail before launch and replace stale
report evidence with an error.

## Pixel comparisons

An untagged YUV source does not identify one RGB color matrix. The original SD
fixture currently defaults to BT.709 in Chrome/Firefox and SMPTE170M in WebKit.
The untagged test uses the decoder's declared matrix/range. A second fixture
explicitly tags both the H.264 stream and its MP4 container as BT.709; all
engines must report that matrix and limited range for that fixture.

Canvas rendering can reconstruct subsampled chroma differently. A requirement
that every RGB pixel match one FFmpeg upsampler rejected valid color edges in
WebKit. Host FFmpeg and FFmpeg.wasm also produced different edge interpolation
with identical scaling options. The reference now decodes YUV independently
with FFmpeg and converts it with fixed, version-independent BT.601/BT.709
coefficients and centered bilinear chroma reconstruction.

The canvas test requires all of the following for the first, middle and last
source frames:

- Correct dimensions and fully opaque alpha for the opaque fixture.
- RGB RMS error at most 3 across every 8×8 area mean, covering the full image.
- RGB RMS error at most 3 at full resolution wherever the reference's 5×5
  neighborhood varies by at most 3; at least 30% of the image must meet this
  condition. The current fixture covers about 64%.

The report retains the unnormalized full-resolution RGB RMS as a diagnostic;
the test does not claim identical RGB pixels at chroma boundaries. The matrix
and quantization coefficients follow [ITU-R BT.601](https://www.itu.int/rec/R-REC-BT.601)
and [ITU-R BT.709](https://www.itu.int/rec/R-REC-BT.709). The distinction between
native planes and rendered color follows the [WebCodecs rendering and copying
contract](https://www.w3.org/TR/webcodecs/#videoframe-interface).

## Independent native-frame check

A separately encoded, tagged 512×256 H.264 fixture keeps native row strides
aligned. This is necessary for the diagnostic `VideoFrame.copyTo` path on the
tested Linux WebKit: copying the original 320px NV12 frame returned zero-filled
lower rows, despite the production canvas path displaying those rows correctly.
Changing the destination stride did not fix that upstream copy behavior. The
suite does not change or bypass the production decoder.

For engines exposing I420 or NV12, the test copies and normalizes plane layout
only, then requires every native YUV byte to equal an independent FFmpeg decode.
There is no error tolerance for those samples. For engines exposing an already
converted RGB format, it normalizes channel order/stride and requires a
full-resolution RGB RMS of at most 3 against independent FFmpeg output. The
report states which comparison ran; it never presents an RGB comparison as
exact YUV validation.

`tool/test/browser_pixel_oracle_test.mjs` covers matrix/range reference values,
missing image regions, wrong colors, errors that cancel in area averages,
alpha loss, padded I420/NV12/RGB layouts and a single corrupted native byte.
Cleanup and engine-selection tests run alongside it with Node's test runner.
