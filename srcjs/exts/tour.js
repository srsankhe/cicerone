// Tour lifecycle: every `cicerone-*` Shiny custom message handler.
import { driver as Driver } from "driver.js";
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
} from "./bridge.js";
import {
  evalFunction,
  evalHooks,
  cleanupStaleHighlights,
  makeTabActivator,
} from "./util.js";
// --- WP6 begin ---
import { armAdvance, disarmAdvance } from "./advance.js";
// --- WP6 end ---

// Hook option names that may arrive from R as strings of JavaScript
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

const STEP_HOOKS = ["onHighlightStarted", "onHighlighted", "onDeselected"];

const POPOVER_HOOKS = ["onPopoverRender", "onCloseClick", "onDoneClick"];

Shiny.addCustomMessageHandler("cicerone-init", function (opts) {
  const id = opts.id || (opts.globals && opts.globals.id);
  const config = opts.globals || {};
  delete config.id;

  active[id] = false;
  pendingReason[id] = null;

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
  // (nextStep) or are the consumer's own business (function).
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

  // strip leaked driver-active-element tags on every transfer;
  // note: a step-level onHighlightStarted overrides this hook, so the
  // step loop below re-injects the cleanup there
  const userHighlightStarted = config.onHighlightStarted;
  config.onHighlightStarted = (element, step, hookOpts) => {
    cleanupStaleHighlights();
    if (userHighlightStarted) userHighlightStarted(element, step, hookOpts);
  };

  // always notify Shiny of state when a step is highlighted; the first
  // highlight of a drive() also fires `_started`/event "started" (but not
  // a subsequent move_to(), which re-highlights without a fresh drive())
  const userHighlighted = config.onHighlighted;
  config.onHighlighted = (element, step, hookOpts) => {
    if (userHighlighted) userHighlighted(element, step, hookOpts);
    const state = getStateData(drivers[id]);
    emitInput(id, "state", state, false);
    if (!active[id]) {
      active[id] = true;
      emitInput(id, "started", {
        index: state.index,
        total_steps: state.total_steps,
      });
      emitEvent(id, "started", state);
    }
    emitEvent(id, "highlighted", state);
    // --- WP6 begin ---
    armAdvance(id, step);
    // --- WP6 end ---
  };

  // --- WP6 begin ---
  // config-level onDeselected: fires whenever the tour moves away from a
  // step, including on destroy() (driver.js's `h()` calls onDeselected
  // just before onDestroyed when there was an active step -- see
  // driver.js.mjs). A step-level onDeselected (step(on_deselected = ))
  // overrides this the same way a step-level onHighlighted overrides
  // onHighlighted above, so the step loop below re-wraps it there too.
  const userDeselected = config.onDeselected;
  config.onDeselected = (element, step, hookOpts) => {
    disarmAdvance(id);
    if (userDeselected) userDeselected(element, step, hookOpts);
  };
  // --- WP6 end ---

  // always notify Shiny when next/previous is clicked
  const origConfigNext = config.onNextClick;
  const origConfigDone = config.onDoneClick;
  const origConfigClose = config.onCloseClick;

  config.onNextClick = wrapNext(id, origConfigNext);
  config.onPrevClick = wrapPrevious(id, config.onPrevClick);
  config.onCloseClick = wrapClose(id, origConfigClose);

  // driver.js only calls onDoneClick when it is defined, and only on the
  // last non-skipped step; defining it unconditionally means driver.js
  // stops falling back to onNextClick there (see `L()` in
  // driver.js.mjs), so this wrapper resolves that same fallback chain
  // itself, using the ORIGINAL (pre-wrap) hooks -- calling the already
  // wrapped onNextClick here would double-emit `_next` and call
  // moveNext() right before we destroy().
  config.onDoneClick = wrapDone(id, (step) => {
    const popover = (step && step.popover) || {};
    return (
      popover._cicOrigDone ||
      origConfigDone ||
      popover._cicOrigNext ||
      origConfigNext
    );
  });

  // always notify Shiny when the tour is closed/destroyed
  const userDestroyed = config.onDestroyed;
  config.onDestroyed = (element, step, hookOpts) => {
    // --- WP6 begin ---
    // usually already a no-op here (onDeselected above already disarmed
    // on the way out); kept as a safety net for the one path that skips
    // onDeselected entirely -- destroy() called while nothing is active.
    disarmAdvance(id);
    // --- WP6 end ---
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

    pendingReason[id] = null;
    active[id] = false;

    Shiny.setInputValue("cicerone_reset", true, { priority: "event" });
    emitInput(id, "reset", true);
  };

  const steps = opts.steps || [];
  steps.forEach((step) => {
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

    // --- WP6 begin ---
    // a step-level onHighlighted/onDeselected (step(on_highlighted = )/
    // step(on_deselected = )) overrides the config-level hooks wrapped
    // above (`f=n?.onHighlighted||e.getConfig("onHighlighted")` /
    // `m=a?.onDeselected||e.getConfig("onDeselected")` in driver.js.mjs),
    // so a step that defines either must re-run arm/disarm itself here,
    // the same way `userStart` above re-runs cleanupStaleHighlights for a
    // step-level override of onHighlightStarted.
    if (step.onHighlighted) {
      const userStepHighlighted = step.onHighlighted;
      step.onHighlighted = (element, s, hookOpts) => {
        userStepHighlighted(element, s, hookOpts);
        armAdvance(id, s);
      };
    }
    if (step.onDeselected) {
      const userStepDeselected = step.onDeselected;
      step.onDeselected = (element, s, hookOpts) => {
        disarmAdvance(id);
        userStepDeselected(element, s, hookOpts);
      };
    }
    // --- WP6 end ---

    if (step.popover) {
      evalHooks(step.popover, POPOVER_HOOKS);

      // stash the ORIGINAL (pre-wrap) done/next hooks of this step's
      // popover for the config-level onDoneClick fallback above, before
      // wrapping onNextClick below turns the latter into a wrapNext()
      // closure
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
    }
  });

  config.steps = steps;
  drivers[id] = Driver(config);
});

Shiny.addCustomMessageHandler("cicerone-start", function (opts) {
  if (!drivers[opts.id]) return console.warn("cicerone: no tour", opts.id);
  drivers[opts.id].drive(opts.step);
});

Shiny.addCustomMessageHandler("cicerone-reset", function (opts) {
  if (!drivers[opts.id]) return;
  pendingReason[opts.id] = "programmatic";
  drivers[opts.id].destroy();
});

Shiny.addCustomMessageHandler("cicerone-next", function (opts) {
  if (!drivers[opts.id]) return;
  // $move_forward() on the last step completes the tour (see advance.js)
  if (drivers[opts.id].isLastStep()) pendingReason[opts.id] = "done";
  drivers[opts.id].moveNext();
});

Shiny.addCustomMessageHandler("cicerone-previous", function (opts) {
  if (!drivers[opts.id]) return;
  drivers[opts.id].movePrevious();
});

Shiny.addCustomMessageHandler("cicerone-move-to", function (opts) {
  if (!drivers[opts.id]) return;
  drivers[opts.id].moveTo(opts.step);
});

Shiny.addCustomMessageHandler("cicerone-refresh", function (opts) {
  if (!drivers[opts.id]) return;
  drivers[opts.id].refresh();
});

Shiny.addCustomMessageHandler("cicerone-highlight", function (opts) {
  if (!drivers[opts.id]) return;
  drivers[opts.id].highlight({ element: opts.el });
});

// standalone highlight: initialise() + highlight()
Shiny.addCustomMessageHandler("cicerone-highlight-man", function (opts) {
  const id = opts.id;
  delete opts.id;
  if (!drivers[id])
    drivers[id] = Driver({ onHighlightStarted: cleanupStaleHighlights });
  if (opts.popover) {
    evalHooks(opts.popover, POPOVER_HOOKS);
    if (opts.popover.onNextClick) {
      opts.popover.onNextClick = wrapNext(
        id,
        evalFunction(opts.popover.onNextClick),
      );
    }
    if (opts.popover.onPrevClick) {
      opts.popover.onPrevClick = wrapPrevious(
        id,
        evalFunction(opts.popover.onPrevClick),
      );
    }
  }
  evalHooks(opts, STEP_HOOKS);

  // --- WP6 begin ---
  // mirrors the step-loop wrap in cicerone-init above: this ad hoc
  // driver has no config-level onHighlighted/onDeselected to piggyback
  // arm/disarm on, so wrap opts's own hooks directly when advance_on/
  // advance_when are set.
  if (opts.advanceOn || opts.advanceWhen) {
    const userHighlighted = opts.onHighlighted;
    const userDeselected = opts.onDeselected;
    opts.onHighlighted = (element, step, hookOpts) => {
      if (userHighlighted) userHighlighted(element, step, hookOpts);
      armAdvance(id, step);
    };
    opts.onDeselected = (element, step, hookOpts) => {
      disarmAdvance(id);
      if (userDeselected) userDeselected(element, step, hookOpts);
    };
  }
  // --- WP6 end ---

  drivers[id].highlight(opts);
});
