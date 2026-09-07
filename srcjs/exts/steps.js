// WP4: step/config preparation, extracted from `cicerone-init` so that
// `cicerone-set-steps`/`cicerone-set-config` (and `cicerone-start`'s
// `show_if` filtering) reuse the exact same wrapping logic instead of
// duplicating it -- see the acceptance note in the WP4 plan: `prepareSteps`
// is meant to be the only place steps get wrapped.
import {
  drivers,
  active,
  pendingReason,
  getStateData,
  stateFromHookOpts,
  wrapNext,
  wrapPrevious,
  wrapDone,
  wrapClose,
  emitInput,
  emitEvent,
  // --- async-safety begin ---
  bumpNavGen,
  // --- async-safety end ---
} from "./bridge.js";
import {
  evalFunction,
  evalHooks,
  cleanupStaleHighlights,
  makeTabActivator,
} from "./util.js";
import { armAdvance, disarmAdvance } from "./advance.js";
import { wrapPopoverRender } from "./progress.js";
// --- WP5 begin ---
import { recordOnStarted, recordOnHighlighted, recordOnEnded } from "./persist.js";
// --- WP5 end ---

// Hook option names that may arrive from R as strings of JavaScript.
const CONFIG_HOOKS = [
  "onPopoverRender",
  "onHighlightStarted",
  "onHighlighted",
  "onDeselected",
  "onDestroyStarted",
  "onDestroyed",
  "onNextClick",
  "onPrevClick",
  "onCloseClick",
  "onDoneClick",
];

// Also used by tour.js's `cicerone-highlight-man` handler (the ad hoc
// standalone highlight driver, which never goes through prepareConfig/
// prepareSteps), hence exported.
export const STEP_HOOKS = ["onHighlightStarted", "onHighlighted", "onDeselected"];

export const POPOVER_HOOKS = ["onPopoverRender", "onCloseClick", "onDoneClick"];

// allSteps[id]: the full prepared step list (before any `show_if`
// filtering), so `cicerone-start` can re-evaluate `show_if` against the
// complete set on every drive(), and the wrapped `onDestroyed` (tour.js,
// via prepareConfig below) can restore it after a drive narrows the live
// driver's steps with `setSteps()`. Published as `window.cicerone.steps`
// by a 1-line attach in cicerone.js, mirroring `advanceListeners` (WP6).
export let allSteps = {};

// Config-level highlight bookkeeping, factored out of prepareConfig()'s
// own `onHighlighted` wrap below so prepareSteps()'s step-level re-wrap
// (immediately below) can run the exact same bookkeeping. driver.js
// calls a step's OWN `onHighlighted` INSTEAD of the config-level one
// whenever the step defines one (the same last-one-defined-wins contract
// `onNextClick`/`onCloseClick`/`onDoneClick`/`onPopoverRender` already
// have here) -- before this factoring, a step-level `on_highlighted`
// only re-armed `advance_on`/`advance_when` and skipped `_state`,
// `_started`/the active flag, `event:"started"`/`"highlighted"`, and the
// WP5 persisted-record writes entirely for that one step.
const highlightBookkeeping = (id, element, step, hookOpts) => {
  const state = getStateData(drivers[id]);
  emitInput(id, "state", state, false);
  if (!active[id]) {
    active[id] = true;
    emitInput(id, "started", {
      index: state.index,
      total_steps: state.total_steps,
    });
    emitEvent(id, "started", state);
    // --- WP5 begin: persisted record write on start ---
    recordOnStarted(id, state.index);
    // --- WP5 end ---
  }
  emitEvent(id, "highlighted", state);
  // --- WP5 begin: persisted record write on each highlight ---
  recordOnHighlighted(id, state.index);
  // --- WP5 end ---
  armAdvance(id, step);
};

// Per-step wrapping: tab activation, hook eval, wrapNext/wrapPrevious/
// wrapClose, `_cicOrigDone`/`_cicOrigNext` stashing, WP6 arm/disarm
// re-wraps, and WP9's per-step popover-render wrap. Mutates and returns
// the same array. `config` is accepted (matching `prepareConfig`'s
// signature) but not currently read here -- per-step wrapping only needs
// `id` for the wrap* closures.
export const prepareSteps = (id, steps, config) => {
  (steps || []).forEach((step) => {
    // `show_if` (R) arrives as a string of JavaScript, same as any other
    // hook; unlike the hooks in STEP_HOOKS it is read by `cicerone-start`
    // (tour.js), not driver.js itself, so it is not one of driver.js's
    // own callback slots and is evaluated here on its own.
    step.showIf = evalFunction(step.showIf);

    // step-level onHighlightStarted overrides the config-level hook in
    // driver.js, so any step that defines one (directly or via tab
    // activation) must run the stale-highlight cleanup itself
    const activateTab =
      step.tab_id && step.tab ? makeTabActivator(step.tab_id, step.tab) : null;
    const userStart = evalFunction(step.onHighlightStarted);
    if (activateTab || userStart) {
      step.onHighlightStarted = (element, s, hookOpts) => {
        cleanupStaleHighlights();
        if (activateTab) activateTab();
        if (userStart) userStart(element, s, hookOpts);
      };
    }
    delete step.tab_id;
    delete step.tab;

    evalHooks(step, STEP_HOOKS);

    // a step-level onHighlighted/onDeselected (step(on_highlighted = )/
    // step(on_deselected = )) overrides the config-level hooks wrapped by
    // prepareConfig, so a step that defines either must re-run the same
    // bookkeeping itself here, the same way `userStart` above re-runs
    // cleanupStaleHighlights for a step-level override of
    // onHighlightStarted. onHighlighted's full bookkeeping (`_state`,
    // `_started`, the `started`/`highlighted` events, the WP5 persisted-
    // record writes, and armAdvance) lives in highlightBookkeeping()
    // above, shared with prepareConfig()'s config-level wrap.
    if (step.onHighlighted) {
      const userStepHighlighted = step.onHighlighted;
      step.onHighlighted = (element, s, hookOpts) => {
        userStepHighlighted(element, s, hookOpts);
        highlightBookkeeping(id, element, s, hookOpts);
      };
    }
    if (step.onDeselected) {
      const userStepDeselected = step.onDeselected;
      step.onDeselected = (element, s, hookOpts) => {
        disarmAdvance(id);
        userStepDeselected(element, s, hookOpts);
      };
    }

    if (step.popover) {
      evalHooks(step.popover, POPOVER_HOOKS);

      // stash the ORIGINAL (pre-wrap) done/next hooks of this step's
      // popover for prepareConfig's onDoneClick fallback, before wrapping
      // onNextClick below turns the latter into a wrapNext() closure
      step.popover._cicOrigDone = step.popover.onDoneClick;
      step.popover._cicOrigNext = evalFunction(step.popover.onNextClick);

      if (step.popover.onNextClick) {
        step.popover.onNextClick = wrapNext(id, step.popover._cicOrigNext);
      }
      if (step.popover.onPrevClick) {
        step.popover.onPrevClick = wrapPrevious(
          id,
          evalFunction(step.popover.onPrevClick),
        );
      }
      if (step.popover.onCloseClick) {
        step.popover.onCloseClick = wrapClose(id, step.popover.onCloseClick);
      }
      // Copilot review: a step-level onDoneClick was stashed into
      // _cicOrigDone (for prepareConfig's fallback chain below) but left
      // in place raw/unwrapped. driver.js's own resolver (`L()` in
      // driver.js.mjs) picks `step.popover.onDoneClick||config.onDoneClick`
      // on the last step -- popover-level wins whenever the step defines
      // one, the same precedence onNextClick/onCloseClick already have
      // here -- so an unwrapped step-level onDoneClick bypassed
      // prepareConfig's wrapDone() entirely: no `_next`/`event:"done"`, no
      // destroy() unless the user hook did it itself. Wrap it the same way.
      if (step.popover.onDoneClick) {
        step.popover.onDoneClick = wrapDone(id, () => step.popover._cicOrigDone);
      }
    }
  });

  // WP9: per-step popover-render wrap. A single pass over the whole,
  // now-fully-wrapped array; `wrapPopoverRender()` only touches
  // `step.popover.onPopoverRender` for steps that define one -- the
  // throwaway `{ steps }` holder means its (separate) config-level
  // `onPopoverRender` wrap runs against a scratch object nobody reads,
  // so this call only ever has the per-step effect. The config-level
  // wrap itself is prepareConfig's concern (below), run once against the
  // real config.
  wrapPopoverRender(id, { steps: steps || [] });

  return steps || [];
};

// Tag a just-produced wrapper closure so a later prepareConfig() re-run
// (see `cicerone-set-config`, tour.js) recognises it and does not wrap it
// again -- nesting wrappers would double-fire Shiny inputs/events and, for
// onNextClick/onDoneClick, call moveNext()/destroy() twice.
const tag = (fn) => {
  if (typeof fn === "function") fn._cicPrepared = true;
  return fn;
};
const isPrepared = (fn) => typeof fn === "function" && fn._cicPrepared === true;

// Config-level wrapping: everything `cicerone-init` used to do directly
// to `config` before looping over steps. Mutates `config` in place and
// returns it.
//
// Idempotent by design: `cicerone-set-config` re-runs this on
// `{...drivers[id].getConfig(), ...newGlobals}` (minus `steps`), whose
// hooks are already the wrapped closures from a previous prepareConfig()
// call (see tour.js). Each wrap below is skipped when the current value
// is already tagged `_cicPrepared`, so an unchanged hook is left as-is
// (no nested wrapper) and only a genuinely new raw hook (a string, a
// plain function, or absent) gets wrapped. `evalHooks()` and the
// `overlayClickBehavior` replacement are naturally idempotent already
// (they only act on strings/"close"/undefined, never on an already-
// resolved function), so they need no such guard.
export const prepareConfig = (id, config) => {
  // string hooks -> functions
  evalHooks(config, CONFIG_HOOKS);
  if (
    typeof config.overlayClickBehavior === "string" &&
    !["close", "nextStep"].includes(config.overlayClickBehavior)
  ) {
    config.overlayClickBehavior = evalFunction(config.overlayClickBehavior);
  }
  // driver.js's own "close" string only destroys internally, bypassing
  // every hook; replace it with a function so overlay clicks get tagged
  // "dismissed" like Escape does. Leave "nextStep" and a user-supplied
  // function alone -- those already route through onDoneClick/onNextClick
  // (nextStep) or are the consumer's own business (function, including
  // our own replacement from a previous prepareConfig() run).
  if (
    config.overlayClickBehavior === "close" ||
    typeof config.overlayClickBehavior === "undefined"
  ) {
    config.overlayClickBehavior = (element, step, hookOpts) => {
      if (!hookOpts.config.allowClose) return;
      pendingReason[id] = "dismissed";
      if (drivers[id] && drivers[id].isActive()) drivers[id].destroy();
    };
  }

  // strip leaked driver-active-element tags on every transfer; note: a
  // step-level onHighlightStarted overrides this hook, so prepareSteps
  // re-injects the cleanup there for a step that defines one
  if (!isPrepared(config.onHighlightStarted)) {
    const userHighlightStarted = config.onHighlightStarted;
    config.onHighlightStarted = tag((element, step, hookOpts) => {
      cleanupStaleHighlights();
      if (userHighlightStarted) userHighlightStarted(element, step, hookOpts);
    });
  }

  // always notify Shiny of state when a step is highlighted; the first
  // highlight of a drive() also fires `_started`/event "started" (but not
  // a subsequent move_to(), which re-highlights without a fresh drive())
  if (!isPrepared(config.onHighlighted)) {
    const userHighlighted = config.onHighlighted;
    config.onHighlighted = tag((element, step, hookOpts) => {
      if (userHighlighted) userHighlighted(element, step, hookOpts);
      highlightBookkeeping(id, element, step, hookOpts);
    });
  }

  // config-level onDeselected: fires whenever the tour moves away from a
  // step, including on destroy() (driver.js's `h()` calls onDeselected
  // just before onDestroyed when there was an active step). A step-level
  // onDeselected overrides this the same way a step-level onHighlighted
  // overrides onHighlighted above, so prepareSteps re-wraps it there too.
  if (!isPrepared(config.onDeselected)) {
    const userDeselected = config.onDeselected;
    config.onDeselected = tag((element, step, hookOpts) => {
      disarmAdvance(id);
      if (userDeselected) userDeselected(element, step, hookOpts);
    });
  }

  // always notify Shiny when next/previous is clicked
  const origConfigNext = config.onNextClick;
  const origConfigDone = config.onDoneClick;
  const origConfigClose = config.onCloseClick;

  if (!isPrepared(config.onNextClick)) {
    config.onNextClick = tag(wrapNext(id, origConfigNext));
  }
  if (!isPrepared(config.onPrevClick)) {
    config.onPrevClick = tag(wrapPrevious(id, config.onPrevClick));
  }
  if (!isPrepared(config.onCloseClick)) {
    config.onCloseClick = tag(wrapClose(id, origConfigClose));
  }

  // driver.js only calls onDoneClick when it is defined, and only on the
  // last non-skipped step; defining it unconditionally means driver.js
  // stops falling back to onNextClick there, so this wrapper resolves
  // that same fallback chain itself, using the ORIGINAL (pre-wrap) hooks
  // -- calling the already wrapped onNextClick here would double-emit
  // `_next` and call moveNext() right before we destroy().
  if (!isPrepared(config.onDoneClick)) {
    config.onDoneClick = tag(
      wrapDone(id, (step) => {
        const popover = (step && step.popover) || {};
        return (
          popover._cicOrigDone ||
          origConfigDone ||
          popover._cicOrigNext ||
          origConfigNext
        );
      }),
    );
  }

  // always notify Shiny when the tour is closed/destroyed
  if (!isPrepared(config.onDestroyed)) {
    const userDestroyed = config.onDestroyed;
    config.onDestroyed = tag((element, step, hookOpts) => {
      // usually already a no-op here (onDeselected above already disarmed
      // on the way out); kept as a safety net for the one path that skips
      // onDeselected entirely -- destroy() called while nothing is active.
      disarmAdvance(id);
      // async-safety: the catch-all bump for every destroy path that
      // actually reaches driver.js's teardown (done, close, dismissed,
      // superseded, a user hook calling opts.driver.destroy() directly,
      // ...) -- see the `navGen` note in bridge.js. cicerone-reset/
      // destroy-all/exclusive-supersede bump their own id(s) directly
      // too, since destroy() on a driver that was never actually active
      // (e.g. reset while still waiting on wait_for_visible for the very
      // first step) never reaches this hook at all.
      bumpNavGen(id);
      if (userDestroyed) userDestroyed(element, step, hookOpts);

      const reason = pendingReason[id] || "dismissed";
      const state = stateFromHookOpts(hookOpts);

      emitInput(id, "ended", {
        reason: reason,
        completed: reason === "done",
        index: state.index,
        total_steps: state.total_steps,
      });
      emitEvent(id, "ended", state);
      // --- WP5 begin: persisted record write on end ---
      recordOnEnded(id, reason, state.index);
      // --- WP5 end ---

      pendingReason[id] = null;
      active[id] = false;

      Shiny.setInputValue("cicerone_reset", true, { priority: "event" });
      emitInput(id, "reset", true);

      // --- WP4 begin: restore the full step list ---
      // `cicerone-start`'s `show_if` filtering (tour.js) narrows the live
      // driver's steps with `setSteps()` before drive(); restore the full
      // prepared list here so the next `$start()` re-evaluates every
      // predicate fresh (e.g. a checkbox a predicate reads may have
      // changed since this run). Safe to call from inside onDestroyed:
      // driver.js's own `h()` has already reset internal state by the
      // time this hook runs, and `setSteps()`'s own `resetState()` call
      // is then a no-op on top of that.
      if (drivers[id]) drivers[id].setSteps(allSteps[id] || []);
      // --- WP4 end ---
    });
  }

  // WP9 config-level popover-render wrap (the per-step half lives in
  // prepareSteps above). Guarded the same way as every other hook here.
  if (!isPrepared(config.onPopoverRender)) {
    wrapPopoverRender(id, config);
    tag(config.onPopoverRender);
  }

  return config;
};
