// WP9: progress bar / dots rendering.
//
// driver.js can only ever show a single `progressText` string with
// `{{current}}`/`{{total}}` substituted once each (see the `P`/`d`
// constants and the `.replace()` chain building `progressText` in
// dist/driver.js.mjs); it has no notion of a bar or a dynamic dot row.
// `wrapPopoverRender` layers that on top of `onPopoverRender` instead:
// on every popover render it reads the active step/total step count off
// the same `opts` driver.js already hands `onPopoverRender`, stamps two
// CSS custom properties plus a style class onto `popover.wrapper`, then
// calls through to whatever `onPopoverRender` was already there.
//
// `progressStyle` travels on the step's `popover` object (sibling to
// `showProgress`/`progressText`, which is where driver.js's own
// `Popover` type keeps its progress-related fields -- see
// `driver.js.d.ts`), and on the top-level config object for the
// tour-wide default, as a key driver.js itself never reads. Verified
// against dist/driver.js.mjs: the live config store is built with a
// plain object spread (`e = {...defaults, ...t}` in `ne()`/`configure`),
// and the step object that reaches `onPopoverRender`'s
// `opts.state.activeStep` is itself assembled with shallow spreads of
// the exact step/popover objects we pass in `config.steps` (`B()`:
// `{...i, popover: {..., ...a, progressText: d}}` where `a = i.popover`).
// Unknown keys on either object simply ride along untouched; driver.js
// neither reads nor rejects them, so nothing needs to be stripped before
// steps reach it.

const STYLE_CLASSES = {
  bar: "cicerone-progress-bar",
  dots: "cicerone-progress-dots",
};

// Step-level `popover.progressStyle` (any of "text"/"bar"/"dots", sent
// whenever R needs to override the tour's default for one step) wins
// over the tour/config-level one; "text" (the default, and the only
// value ever seen at config level -- R omits the key entirely otherwise)
// means no wrapping class/vars are applied.
const resolveStyle = (opts) => {
  const state = (opts && opts.state) || {};
  const step = state.activeStep || {};
  const stepStyle = step.popover && step.popover.progressStyle;
  if (typeof stepStyle === "string") return stepStyle;

  const config = (opts && opts.config) || {};
  return typeof config.progressStyle === "string" ? config.progressStyle : "text";
};

// Stamp the current/total custom properties and the style class onto the
// just-rendered popover wrapper. driver.js tears down and rebuilds the
// `.driver-popover` element from scratch on every transition (`w()` then
// `x()` in dist/driver.js.mjs), so there is never a stale class or
// property value left over to clear first.
const renderProgress = (popover, opts) => {
  const style = resolveStyle(opts);
  if (style !== "bar" && style !== "dots") return;

  const state = (opts && opts.state) || {};
  const steps = (opts && opts.config && opts.config.steps) || [];
  // a standalone highlight()/initialise()+highlight() popover has no
  // `steps` array and never sets `activeIndex` (driver.js's own
  // `highlight()` bypasses the step-driving code path that does) --
  // treat that as step 1 of 1.
  const total = steps.length || 1;
  const current =
    (typeof state.activeIndex === "number" ? state.activeIndex : 0) + 1;

  const wrapper = popover.wrapper;
  wrapper.style.setProperty("--cicerone-progress-current", current);
  wrapper.style.setProperty("--cicerone-progress-total", total);
  wrapper.classList.add(STYLE_CLASSES[style]);
};

// Wrap one onPopoverRender-shaped hook: render progress first, then hand
// off to whatever the caller already had there (if anything).
const wrap = (fn) => {
  return (popover, opts) => {
    renderProgress(popover, opts);
    if (fn) fn(popover, opts);
  };
};

// Wrap the config-level `onPopoverRender` fallback AND every step's own
// `popover.onPopoverRender`, when defined. driver.js calls the step-level
// hook INSTEAD of the config-level one whenever both exist -- the same
// last-one-defined-wins contract `onNextClick`/`onPrevClick`/
// `onCloseClick`/`onDoneClick` already have in tour.js -- so the
// config-level wrap alone would never run for a step that customises its
// own render hook.
export const wrapPopoverRender = (id, config) => {
  config.onPopoverRender = wrap(config.onPopoverRender);

  (config.steps || []).forEach((step) => {
    if (step.popover && step.popover.onPopoverRender) {
      step.popover.onPopoverRender = wrap(step.popover.onPopoverRender);
    }
  });

  return config;
};
