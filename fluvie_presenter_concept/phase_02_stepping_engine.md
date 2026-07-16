# Phase 2 — Stepping Engine (`Stop`, build model, controller)

**Goal:** The core of the presenter. The `Stop` widget, the compiler that turns a scene into ordered build steps, and the `PresentationController` that walks slides and steps forward and back. Reveal-on-advance: stopped content is hidden until its step, then animates in.

**Depends on:** Phase 1.

**Produces:** `packages/fluvie_presenter/lib/src/stepping/**` and `.../controller/**`.

**Definition of done:** a multi-scene `Video` with `Stop`s steps correctly forward and back; forward plays the authored entrance, back seeks instantly to the prior held state, ambient loops keep running; unit tests for the compiler and controller, golden tests for a slide at each step.

---

## The model (build this exactly)

- A `Video` has N scenes, so N base slides.
- Within a scene, content not wrapped in a `Stop` is **step 0** and plays on slide entry.
- Each `Stop` becomes a later step. Order is document order, with an optional `order` on `Stop` to override. A `Stop` can wrap several elements that reveal together.
- Steps in a slide equal the number of `Stop`s plus one. Advancing past the last step goes to the next slide's step 0. Going back from step 0 goes to the previous slide's last step.
- Forward into a step reveals that step's content and plays its authored entrance from that moment, then holds. Back or jump seeks instantly to the target held state with no reverse animation.

## Epics

### Epic 2.1 — `Stop` widget
1. `Stop({int? order, required List<Widget> children})` (and a single-child convenience). It marks its subtree as a build step. It renders nothing until its step is active, then reveals and lets the children play their entrance.
2. `Stop` carries no animation logic of its own. It defers to the authored animations on its children.
3. **Acceptance:** widget test that a `Stop`'s children are absent from the tree before their step and present after.

### Epic 2.2 — Step compiler
1. Given a scene, walk its subtree to find `Stop`s (and their optional order), and use fluvie's `TimelineIntrospector` to find each stopped element's entrance window.
2. Produce a `SlidePlan` per scene: an ordered list of `Step`s, each with the set of elements to reveal and the entrance duration to play.
3. Handle nested `Stop`s and multiple elements per `Stop`; detect and report an invalid setup (for example, a duplicate explicit `order`) with a clear error.
4. **Acceptance:** unit tests compiling scenes with zero, one, and several `Stop`s, and with explicit ordering, into the expected `SlidePlan`.

### Epic 2.3 — `PresentationController`
1. A Riverpod notifier holding `(slideIndex, stepIndex)`, playback state, and derived values: `totalSlides`, `stepsInCurrentSlide`, `canGoNext`, `canGoBack`, and a `nextPosition` descriptor.
2. Actions: `next`, `back`, `jumpToSlide`, `jumpToStep`, and a flat position ordering that `next` and `back` traverse.
3. Forward advance plays the step entrance through the `LivePlayer`; back and jump seek instantly to the target held state.
4. **Acceptance:** unit tests for traversal across slides and steps, boundary behavior at the first and last position, and that back and jump use instant seek.

### Epic 2.4 — Slide rendering with steps
1. A `SlideView` that renders the current scene at the current step: step 0 content plus every revealed `Stop`, held at the right state, with ambient animations still running.
2. Wire scene-to-scene advancement. Play the authored transition between slides by default, with a config flag to cut instead.
3. **Acceptance:** golden tests for a representative slide at step 0, a middle step, and its final step; a back-navigation test asserting the held state matches the forward-arrived state.

---

## Testing
`packages/fluvie_presenter/test/stepping/` and `.../controller/`. Compiler and controller are pure and get exhaustive unit tests. Slide rendering gets goldens. Use a fake ticker so entrance playback is deterministic.

## Guardrails and side effects
- Reveal-on-advance means the DOM of the scene changes per step. Make sure held states are frame-exact and that re-entering a step (via back then forward) is consistent.
- Ambient (during) animations keep running while held. Only the build progression pauses.
- Keep the compiler independent of the UI so it can be tested without pumping widgets.

## Commit checkpoints
One commit per epic (2.1 to 2.4).
