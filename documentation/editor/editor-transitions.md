# Clip transitions and speed

A hairline is a scene boundary; a bar edge is a clip cut. Dragging a hairline
retimes a scene and everything downstream. A transition at a clip cut blends
two neighbouring clips inside the same scene and lane.

## Dissolve, wipe, zoom and slide

Open **Transitions** above the video timeline and drag a tile onto the cut
between two clips. The cut snaps to the neighbouring pair and starts with a
half-second blend. The transition has its own bar. Drag either edge to change
its duration; a whole drag is one undo step. Select the transition and choose
**Remove transition** to restore the authored clip windows.

Both clips must be direct siblings on the same lane. Their authored windows
must touch, or already overlap by no more than the blend. A duration that does
not fit is refused with its reason. Shared heroes have their own scene-boundary
morph and cannot also be members of a clip transition. Structural edits preserve
the transition whenever the resulting pair still fits. A razor transfers an
outgoing transition to the tail and keeps an incoming one on the head. A cut
inside a blend that leaves too little material is refused
with the engine’s reason.

The default overlapping blend starts the incoming clip early by the blend
length and preserves its duration, so its end also moves earlier. The scene's
length stays fixed: for example, a clip authored at frames 24–48 with a six-frame
overlap plays at 18–42, leaving the scene background at 42–48. Extend the last
clip or shorten the scene if that gap is unwanted. Its picture and source audio
use that same window. Audio fades use
complementary sine/cosine envelopes for constant power and multiply any authored
volume automation. Changing the transition duration changes both envelopes.
A spec with `overlap: false` holds the outgoing picture on its last frame while
the incoming clip starts at the cut; its outgoing source audio fades before
the cut and the incoming audio fades after it, because a held frame has no new
source audio to play.

Custom transitions use the public `registerTransitionStrategy` registry and
`Transition.custom`. A strategy returns its widgets in paint order, bottom
first, and receives eased progress in `(0, 1]`. A cut has no blend window and
cannot be registered as a blend strategy.

## Speed and slow motion

Select a clip and edit **Speed ×** in the inspector. Enable **Rate stretch**
above the timeline to make the bar's right edge change its speed. Both preserve
the selected source in/out points and adjust the displayed duration. Whole-frame
rounding adjusts the stored rate so the same source range is consumed. Extend
the scene first if the requested duration cannot fit. Shared clip chains apply
the requested speed to every member in one undo step, preserving each member's
source in/out, start and geometry. Rate stretch scales their durations together
and puts the last member's end at the dragged edge. If a member cannot fit its
scene or group, or its lane is locked, the whole edit is refused with its reason.

Choose **Add speed ramp** to vary speed over the clip. Edit each stop's rate,
add or remove a middle stop, change its position percentage, and edit the easing
between stops. The source clock is the integral of that curve: picture,
frame extraction, preview and source audio all follow the same clock. Stretching
a ramp scales all its rates together. Rates must stay positive, including
between stops; a curve that crosses zero is refused.

Slipping a ramp translates its source range using that same integrated clock.
The window and easing remain unchanged. A drag captures every shared member's
original source range, so reversing the pointer returns to the original footage
without accumulating offsets.

**Reverse** applies to a constant speed and explicitly drops the clip's source
audio. Use an independent audio track for a rewind sound. Reverse ramps are not
accepted. Razor preserves the complete eased speed curve and source-frame phase
on both halves, including cuts between original ramp stops. Stops outside a half’s
visible window remain in its curve so playback does not restart the easing.

## Related editing tools

- [NLE timeline](editor-nle-timeline.md): lanes, cuts, trim tools and shortcuts.
- [Continuity](editor-continuity.md): overlays, shared chains and scene duration.
