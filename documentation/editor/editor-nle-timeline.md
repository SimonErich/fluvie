# Editing the video timeline

The timeline uses one absolute frame ruler for the whole video. **Quick** shows
an unnumbered Picture lane and Audio lane; **Edit** shows the declared numbered
video and audio lanes, effects and transitions. Switching workspaces changes
presentation without rewriting the document or its lane assignments.

Drag a bar to move it in time and onto a compatible lane. Drag its edges to
trim. Snapping uses nearby bar edges, the playhead, scene boundaries, markers,
in/out marks and frame zero. Hold Ctrl (Cmd on macOS) to bypass snapping. Click
selects a bar, Shift-click extends a range, Ctrl/Cmd-click toggles membership,
and dragging empty space selects a rectangle across lanes.

The **Clip** and **Sequence** menus, command palette and keyboard all use the
same command registry. Set in/out with I/O, razor the selection at the playhead
with B, and use Ripple delete, Lift or Extract for the selected material. The
[shortcut reference](editor-shortcuts.md) lists the current bindings.

A ripple closes gaps within each scene and preserves scene duration. A shared
chain is edited across all its memberships in one undo step. Razor divides it
into independent left and right chains; a marked range can cut across several
members. Geometry stays local to each member. Locked lanes refuse edits. Clips
that overlap a deleted gap remain in place and the editor reports this.

Roll changes the cut between adjacent clips. Slip changes source in/out while
holding the bar's window. Slide moves a bar and adjusts its neighbours. These
operations refuse trigger-driven timing or source ranges they cannot determine;
the reason appears above the timeline. Slip also works across a shared chain:
each member retains its own source range, rate, timing and geometry, and a source
start clamps the whole gesture. Roll and Slide require a single scene's neighbour
pair; a logical chain spanning several scene clocks is refused with guidance to
use its timing handles. They do not guess a neighbour in another scene.
Audio with an explicit placement can be moved, while trigger-based placement is
preserved. Music with a known source trim supports Razor, Lift, Extract and
ripple edits.
Those cuts retain volume automation and fades across the split. Looped, anchored
or trigger-placed audio explains why it cannot be cut without changing its
authored timing.

Declared lane labels offer lock, mute and preview-only solo. Drag a label to
reorder lanes; video lane reorder also rewrites element order so the canvas,
layers list and hit testing agree. Empty declared lanes remain available as drop
targets. Cached waveforms and filmstrips appear as media becomes available;
visible spans drive thumbnail requests and off-screen rows are virtualized.

A ruler hairline is a scene boundary. Dragging it retimes the preceding scene;
its Length field edits the same value. A bar edge is a clip cut. See
[continuity](editor-continuity.md) and [transitions and speed](editor-transitions.md)
for the distinction and the available rate-stretch and blend tools.
