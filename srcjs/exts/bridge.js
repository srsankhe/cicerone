// The Shiny <-> driver.js bridge: instance registries and the wrappers
// that keep Shiny inputs in sync with tour state.
import { stripHash } from "./util.js";

// driver.js 1.x instances, keyed by cicerone id
export let drivers = {};
// hints instances, keyed by cicerone id
export let hinters = {};

// Per-id "has `_cicerone_started` already fired for the current drive()"
// flag. Set the first time `onHighlighted` runs after init/drive, cleared
// by the wrapped `onDestroyed`. `move_to()` re-highlights without going
// through `drive()` again, so it must not flip this back to false.
export let active = {};

// Per-id reason for the destroy() about to happen, set by whichever
// wrapper initiates it (done/close/reset/dismissed) *before* calling
// destroy(). Read (and cleared) by the wrapped `onDestroyed`, which falls
// back to "dismissed" when nothing set it (Escape and a plain overlay
// click with a custom `overlayClickBehavior` function bypass every other
// wrapper and go straight to driver.js's internal destroy).
export let pendingReason = {};

// Snapshot of the driver state sent to Shiny.
// `highlighted`, `previous`, `before_previous` and `has_next` are kept
// for backwards compatibility with cicerone < 2.0.0.
export const getStateData = (d) => {
  if (!d) return null;

  const activeStep = d.getActiveStep();
  const previousStep = d.getPreviousStep();

  const highlighted = activeStep ? stripHash(activeStep.element) : null;
  const previousEl = previousStep ? stripHash(previousStep.element) : null;

  return {
    highlighted: highlighted,
    previous: highlighted,
    before_previous: previousEl,
    has_next: d.hasNextStep(),
    has_previous: d.hasPreviousStep(),
    index: d.getActiveIndex(),
    is_first: d.isFirstStep(),
    is_last: d.isLastStep(),
    total_steps: (d.getConfig().steps || []).length,
  };
};

// Same shape as (the parts of) `getStateData` that `emitEvent` needs, but
// read from a driver.js `HookOpts` argument instead of the live driver.
// Needed for `onDestroyed`: by the time it fires, driver.js has already
// reset its live state (`h()` in driver.js.mjs calls `resetState()` before
// invoking `onDestroyed`), so `getActiveIndex()`/`getActiveStep()` would
// return `undefined`. The pre-reset snapshot survives in `opts.state`/
// `opts.config`, which driver.js passes explicitly for this one hook.
export const stateFromHookOpts = (opts) => {
  const state = (opts && opts.state) || {};
  const steps = (opts && opts.config && opts.config.steps) || [];
  const activeStep = state.activeStep;

  return {
    index: typeof state.activeIndex === "number" ? state.activeIndex : null,
    highlighted: activeStep ? stripHash(activeStep.element) : null,
    total_steps: steps.length,
  };
};

// Push a value to the `{id}_cicerone_{suffix}` Shiny input. `event = true`
// (the default) sets `priority: "event"`, matching every existing bridge
// input except `{id}_cicerone_state`, which is set without event priority.
export const emitInput = (id, suffix, value, event = true) => {
  Shiny.setInputValue(
    id + "_cicerone_" + suffix,
    value,
    event ? { priority: "event" } : undefined,
  );
};

// Push `{id}_cicerone_event` = {type, index, element, total_steps, time},
// in addition to whatever specific input the caller also emits. `state` is
// either a `getStateData()`/`stateFromHookOpts()` result or `null`.
export const emitEvent = (id, type, state) => {
  const s = state || {};
  emitInput(id, "event", {
    type: type,
    index: typeof s.index === "number" ? s.index : null,
    element: s.highlighted != null ? s.highlighted : null,
    total_steps: typeof s.total_steps === "number" ? s.total_steps : null,
    time: new Date().toISOString(),
  });
};

// Wrap a user supplied onNextClick so that:
// 1. the `{id}_cicerone_next` Shiny input always fires
// 2. the tour still advances (driver.js 1.x hands control over
//    when onNextClick is overridden) unless the user callback
//    explicitly returns `false`
export const wrapNext = (id, fn) => {
  return (element, step, opts) => {
    const state = getStateData(drivers[id]);
    emitInput(id, "next", state);
    emitEvent(id, "next", state);
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].moveNext();
  };
};

export const wrapPrevious = (id, fn) => {
  return (element, step, opts) => {
    const state = getStateData(drivers[id]);
    emitInput(id, "previous", state);
    emitEvent(id, "previous", state);
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].movePrevious();
  };
};

// Wrap a resolved "done" hook (config- or popover-level; `getFn(step)`
// decides which original, unwrapped user function applies to the active
// step -- see tour.js). Unless it returns `false`, this always emits
// `_next` (matching the onNextClick fallback it replaces on the last
// step) and `event:"done"`, tags `pendingReason` and destroys the tour.
export const wrapDone = (id, getFn) => {
  return (element, step, opts) => {
    const fn = getFn(step);
    const state = getStateData(drivers[id]);
    // tag the reason *before* calling the user hook: a done/next hook is
    // documented to be allowed to call `opts.driver.destroy()` itself, and
    // that would run onDestroyed synchronously, inside this call, before
    // we otherwise get a chance to set it
    const previousReason = pendingReason[id];
    pendingReason[id] = "done";
    let out;
    if (fn) out = fn(element, step, opts);
    emitInput(id, "next", state);
    emitEvent(id, "done", state);
    if (out !== false) {
      if (drivers[id] && drivers[id].isActive()) drivers[id].destroy();
    } else {
      // hook declined: don't leave a stale "done" reason for some later,
      // unrelated destroy() to pick up
      pendingReason[id] = previousReason;
    }
  };
};

// Wrap a config- or popover-level onCloseClick the same way, tagging
// "close" instead. Guarded with `isActive()` so a user hook that already
// called `opts.driver.destroy()` itself (the documented 2.0.0 pattern)
// does not throw on our own follow-up `destroy()`.
export const wrapClose = (id, fn) => {
  return (element, step, opts) => {
    const state = getStateData(drivers[id]);
    const previousReason = pendingReason[id];
    pendingReason[id] = "close";
    let out;
    if (fn) out = fn(element, step, opts);
    emitEvent(id, "close", state);
    if (out !== false) {
      if (drivers[id] && drivers[id].isActive()) drivers[id].destroy();
    } else {
      pendingReason[id] = previousReason;
    }
  };
};
