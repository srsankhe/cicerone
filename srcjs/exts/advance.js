// WP6: advance_on / advance_when arming for tour steps.
//
// A step advances not only by clicking the highlighted element
// (driver.js's own `advanceOnClick`), but also by a named DOM event on
// *any* element (`advance_on`) or a JavaScript predicate re-evaluated as
// the page changes (`advance_when`). Both live in one registry entry per
// cicerone id -- `advanceListeners` -- so that whichever mechanism fires
// first tears down both, and so a host page (or a test) can inspect what,
// if anything, is currently armed. `window.cicerone.advanceListeners`
// publishes this object; see the 1-line attachment in cicerone.js.
import { drivers, getStateData, emitEvent, pendingReason } from "./bridge.js";
import { evalFunction, stripHash } from "./util.js";

export const advanceListeners = {};

// Tear down whatever is armed for `id` and drop its registry entry.
// Idempotent: safe to call when nothing is armed, and safe to call twice.
export const disarmAdvance = (id) => {
  const entry = advanceListeners[id];
  if (!entry) return;

  if (entry.el && entry.event && entry.handler) {
    entry.el.removeEventListener(entry.event, entry.handler);
  }
  if (entry.observer) entry.observer.disconnect();
  if (entry.scheduleCheck) {
    document.removeEventListener("input", entry.scheduleCheck);
    document.removeEventListener("change", entry.scheduleCheck);
  }

  delete advanceListeners[id];
};

// Approximates driver.js's `HookOpts` shape for the `advance_when`
// predicate `(step, opts) => boolean`. The public driver instance
// (`drivers[id]`) does not expose the internal `getHookOpts()` that
// cicerone's own hook wrappers receive, so build the same shape from
// what it does expose.
const hookOptsFor = (id) => {
  const d = drivers[id];
  if (!d) return {};
  return {
    config: d.getConfig(),
    state: d.getState(),
    driver: d,
    index: d.getActiveIndex(),
  };
};

// Common tail for both mechanisms: disarm first (so the transition
// `moveNext()` is about to trigger can arm the next step's listeners
// cleanly, without this call clobbering them), tell Shiny, then move.
const fireAdvance = (id, elementLabel) => {
  const state = getStateData(drivers[id]);
  disarmAdvance(id);
  emitEvent(id, "advance", {
    index: state ? state.index : null,
    highlighted: elementLabel != null ? elementLabel : (state ? state.highlighted : null),
    total_steps: state ? state.total_steps : null,
  });
  // advancing off the last step completes the tour: moveNext() destroys
  // directly without going through the Done button's hook resolution, so
  // tag the reason here or onDestroyed would report "dismissed"
  if (drivers[id]) {
    if (drivers[id].isLastStep()) pendingReason[id] = "done";
    drivers[id].moveNext();
  }
};

// Arm `step.advanceOn`/`step.advanceWhen` for the step just highlighted
// on tour `id`. No-op when the step has neither. Always disarms any
// previous entry first, so a step re-highlighted without an intervening
// deselect (driver.js can call `onHighlighted` again for the same
// element) does not leak a duplicate listener/observer.
export const armAdvance = (id, step) => {
  disarmAdvance(id);
  if (!step || (!step.advanceOn && !step.advanceWhen)) return;

  const entry = {};

  if (step.advanceOn && step.advanceOn.element) {
    const selector = step.advanceOn.element;
    const eventName = step.advanceOn.event || "click";
    const el = document.querySelector(selector);
    if (el) {
      const handler = () => fireAdvance(id, stripHash(selector));
      el.addEventListener(eventName, handler, { once: true });
      entry.el = el;
      entry.event = eventName;
      entry.handler = handler;
    } else {
      console.warn("cicerone: advance_on element not found:", selector);
    }
  }

  if (step.advanceWhen) {
    const predicate = evalFunction(step.advanceWhen);
    let scheduled = false;
    const check = () => {
      scheduled = false;
      // stale: this step was disarmed (or replaced) since the check was
      // scheduled -- e.g. the step was left, or advance_on already fired
      if (advanceListeners[id] !== entry) return;
      let result;
      try {
        result = predicate(step, hookOptsFor(id));
      } catch (e) {
        console.warn("cicerone: advance_when predicate threw", e);
        return;
      }
      if (result) fireAdvance(id, null);
    };
    const scheduleCheck = () => {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(check);
    };

    const observer = new MutationObserver(scheduleCheck);
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      characterData: true,
    });
    document.addEventListener("input", scheduleCheck);
    document.addEventListener("change", scheduleCheck);

    entry.observer = observer;
    entry.scheduleCheck = scheduleCheck;
    entry.check = check;
  }

  if (!entry.el && !entry.observer) return;

  advanceListeners[id] = entry;

  // advance_when is evaluated once immediately (synchronously) when the
  // step is highlighted, in addition to the throttled re-evaluation on
  // every subsequent mutation/input/change
  if (entry.check) entry.check();
};
