# Media bin and source monitor

In video mode, **Import media** adds a reusable source to Assets. It does not
place a clip until you choose Place or drag a source range onto the timeline.
The bin supports folders, search and sorting. Imported metadata shows duration,
resolution, source frame rate and audio channel count when the platform can
probe them. Unavailable metadata is stated rather than guessed.

Select an asset to open its source monitor. Scrub independently of the project
playhead and use **I** and **O** while the source monitor has focus to mark its
range. Marks belong to the asset, so repeated placements reuse them. The placed
clip stores its own trim and timeline window; later changes to bin marks do not
retime existing clips. Fractional source rates are converted through source time
rather than treated as the project's frame rate.

Choose Place to use the active lane and playhead, or drag the marked range to a
compatible lane. Locked or incompatible lanes refuse the placement visibly.
Audio ranges also preserve their placement offset and source trim. The source
monitor's **Listen from playhead** action auditions audio; the channel label
identifies the mono preview mix. **Stop listening** ends the audition.

Desktop imports keep file references. Browser imports keep bounded session bytes
and save them in the project bundle, including assets that remain only in the
bin. Save and reopen preserve folders, metadata and marks without changing the
render digest. A plain file-reference project still needs its referenced files
at their saved paths.

Browser video preview supports MP4/MOV containers and codecs available through
WebCodecs. Other containers report the required conversion. Desktop decoding
uses FFmpeg. Source and timeline decode failures offer visible errors; a
filmstrip can be retried after the media becomes available again.

See [Media and bundles](editor-media.md) for portability and
[Workspaces](editor-workspaces.md) for layout and disclosure.
