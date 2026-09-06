// Tour lifecycle: every `cicerone-*` Shiny custom message handler.
import { driver as Driver } from "driver.js";
import {
  drivers,
  active,
  pendingReason,
  getStateData,
  wrapNext,
  wrapPrevious,
  emitEvent,
} from "./bridge.js";
import {
  evalFunction,
  evalHooks,
  cleanupStaleHighlights,
} from "./util.js";
// --- WP6 begin ---
import { armAdvance, disarmAdvance } from "./advance.js";
// --- WP6 end ---
// --- WP7 begin: exclusive start / anchor readiness imports ---
import { stripHash } from "./util.js";
import {
  waitForVisible,
  effectiveWaitForVisible,
} from "./anchor.js";
// --- WP7 end ---
// --- WP4 begin: extracted step/config preparation ---
import {
  prepareSteps,
  prepareConfig,
  allSteps,
  STEP_HOOKS,
  POPOVER_HOOKS,
} from "./steps.js";
// --- WP4 end ---

Shiny.addCustomMessageHandler("cicerone-init", function (opts) {
  const id = opts.id || (opts.globals && opts.globals.id);
  const config = opts.globals || {};
  delete config.id;

  active[id] = false;
  pendingReason[id] = null;

  // --- WP4 begin: config + step preparation (steps.js) ---
  prepareConfig(id, config);

  const prepared = prepareSteps(id, opts.steps || [], config);
  config.steps = prepared;
  allSteps[id] = prepared;
  // --- WP4 end ---

  drivers[id] = Driver(config);
});

Shiny.addCustomMessageHandler("cicerone-start", function (opts) {
  const id = opts.id;
  if (!drivers[id]) return console.warn("cicerone: no tour", id);
  const driver = drivers[id];
  const config = driver.getConfig();

  // --- WP7 begin: exclusive ---
  // `exclusive` defaults to TRUE R-side (see build_config()); anything
  // other than an explicit `false` here keeps that default even if the
  // key were ever absent from config.
  if (config.exclusive !== false) {
    Object.keys(drivers).forEach((otherId) => {
      const other = drivers[otherId];
      if (otherId !== id && other && other.isActive()) {
        pendingReason[otherId] = "superseded";
        other.destroy();
      }
    });
  }
  // --- WP7 end ---

  const driveNow = () => {
    driver.drive(opts.step);
    // --- WP7 begin: render confirmation ---
    // driver.js's own destroy() is synchronous and there is no teardown
    // timer, so a tour that is isActive() one frame after drive() but has
    // no `.driver-popover` in the DOM did not actually render. No
    // automatic retry (see NEWS/plan risk N1): the cause is unproven, and
    // a retry loop risks masking a real bug. Reproduction attempt: WP7's
    // NAS-shape e2e test (test-e2e-exclusive.R).
    //
    // Design note (beyond the plan's literal wording): only flag this when
    // the active step actually defines a `popover` -- a step with no
    // title/description/on_* (`el` alone) deliberately gets no popover
    // from driver.js (see `J()`/`U()` in driver.js.mjs, gated on
    // `n.popover`), so "no `.driver-popover` in the DOM" is expected there,
    // not a failed render. Checked against `getActiveStep()` (the step
    // driver.js actually landed on), not the requested target step, since
    // `skipMissingElement` may have moved the active step already.
    window.requestAnimationFrame(() => {
      const activeStep = driver.getActiveStep();
      if (
        driver.isActive() &&
        activeStep &&
        activeStep.popover &&
        !document.querySelector(".driver-popover")
      ) {
        emitEvent(id, "start_failed", getStateData(driver));
        console.warn(
          "cicerone: tour", id, "is active but rendered no popover",
        );
      }
    });
    // --- WP7 end ---
  };

  // --- WP7 begin: wait_for_visible at start ---
  const steps = config.steps || [];
  const startIndex = opts.step || 0;
  const targetStep = steps[startIndex];
  const waitMs = effectiveWaitForVisible(targetStep, config);
  if (waitMs > 0 && targetStep && targetStep.element) {
    waitForVisible(targetStep.element, { timeout: waitMs, requireVisible: true }).then(
      (result) => {
        if (!result.visible) {
          emitEvent(id, "anchor_timeout", {
            index: startIndex,
            highlighted: stripHash(targetStep.element),
            total_steps: steps.length,
          });
        }
        driveNow();
      },
    );
  } else {
    driveNow();
  }
  // --- WP7 end ---
});

// --- WP7 begin: destroy_all() ---
// Shiny's addCustomMessageHandler() requires a callback of arity 1 (it
// throws "handler must be a function that takes one argument" otherwise,
// synchronously, at registration time -- which, bundled, aborts the rest
// of this module's evaluation); `opts` is unused here, `destroy_all()`
// sends an empty payload.
Shiny.addCustomMessageHandler("cicerone-destroy-all", function (opts) {
  Object.keys(drivers).forEach((id) => {
    const driver = drivers[id];
    if (driver && driver.isActive()) {
      pendingReason[id] = "programmatic";
      driver.destroy();
    }
  });
});
// --- WP7 end ---

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
