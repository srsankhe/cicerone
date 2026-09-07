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
  emitInput,
  // --- async-safety begin ---
  bumpNavGen,
  currentNavGen,
  // --- async-safety end ---
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
// --- WP5 begin: persistence imports ---
import {
  initPersistence,
  setPushedRecord,
  isRunOnceCompleted,
  resumeIndex,
  forgetPersisted,
  persistRecords,
} from "./persist.js";
// --- WP5 end ---

Shiny.addCustomMessageHandler("cicerone-init", function (opts) {
  const id = opts.id || (opts.globals && opts.globals.id);
  const config = opts.globals || {};
  delete config.id;

  active[id] = false;
  pendingReason[id] = null;

  // --- WP5 begin: persistence setup ---
  // cookie backend: read + cache the record now, `document.cookie` is
  // already whatever the browser had when this page loaded, no round
  // trip needed. Adapter backend: nothing to read yet -- `_seen` fires
  // from the `cicerone-persist-record` handler below once R's
  // `persist$read()` result arrives (sent right after this same
  // `cicerone-init` message, so it is always the very next message for
  // this id).
  const persistedRecord = initPersistence(id, opts.persist, opts.version, opts.runOnce);
  if (opts.persist === "cookie") emitInput(id, "seen", persistedRecord);
  // --- WP5 end ---

  // --- WP4 begin: config + step preparation (steps.js) ---
  prepareConfig(id, config);

  const prepared = prepareSteps(id, opts.steps || [], config);
  config.steps = prepared;
  allSteps[id] = prepared;
  // --- WP4 end ---

  drivers[id] = Driver(config);
});

// --- WP4 begin: mutable tours ---
// `$set_steps()`: rebuild the driver's step list from whatever
// `private$steps` currently holds R-side (typically after
// `$clear_steps()$step(...)...`). Always raw (unwrapped) steps -- R never
// round-trips the wrapped JS closures -- so no idempotency concern here,
// unlike prepareConfig.
Shiny.addCustomMessageHandler("cicerone-set-steps", function (opts) {
  const id = opts.id;
  if (!drivers[id]) return console.warn("cicerone: no tour", id);

  const prepared = prepareSteps(id, opts.steps || [], drivers[id].getConfig());
  allSteps[id] = prepared;
  drivers[id].setSteps(prepared);
});

// `$set_config()`: merge the supplied globals over the driver's current
// config and re-apply. driver.js's own `setConfig()` replaces the ENTIRE
// config with `{...driver.js's hardcoded defaults, ...newConfig}` -- it
// does NOT merge with the previously live config (see `configure()`/
// `ne()` in driver.js.mjs: `e={animate:true,...,...t}` on every call).
// Passing only the newly supplied keys would therefore wipe every other
// key already set (our wrapped hooks, `exclusive`, `waitForVisible`, and
// `steps`, none of which are among driver.js's own defaults) back to
// driver.js's stock values. Spreading the full current `getConfig()`
// first avoids that.
//
// `steps` is deliberately restored from the authoritative `allSteps[id]`
// list (not whatever subset `config.steps` happened to hold, e.g. a
// `show_if`-filtered list from the last `cicerone-start`) IN THE SAME
// object passed to `setConfig()`, rather than via a separate
// `drivers[id].setSteps()` call afterward. `setSteps()` is not just "set
// the steps key": it is `d(); t.resetState(); t.setConfig(...)` (see
// driver.js.mjs) -- it wipes ALL live state first, including
// `activeIndex` and the current overlay SVG reference. Calling it
// mid-tour would silently orphan the visible overlay/popover (a new one
// gets created on the next highlight, reading the updated config, but
// the old one is never removed) and would break `moveNext()`/
// `movePrevious()` until the next highlight resets `activeIndex` (both
// read `getState("activeIndex")`, `undefined` right after
// `resetState()`, and no-op). Plain `setConfig()` (`configure()`) touches
// only the config store, never live state, so folding `steps` into one
// `setConfig()` call keeps the tour exactly where it was.
Shiny.addCustomMessageHandler("cicerone-set-config", function (opts) {
  const id = opts.id;
  if (!drivers[id]) return console.warn("cicerone: no tour", id);

  const merged = Object.assign({}, drivers[id].getConfig());
  Object.assign(merged, opts.globals || {});
  merged.steps = allSteps[id] || merged.steps || [];

  prepareConfig(id, merged);
  drivers[id].setConfig(merged);

  // driver.js only ever sets the overlay `<path>`'s `style.fill`/
  // `style.opacity` once, at creation time (`M()` in driver.js.mjs);
  // every later highlight/refresh only rewrites its `d` attribute (`A()`),
  // never fill/opacity. A mid-tour `overlay_color`/`overlay_opacity`
  // change would otherwise silently not take visible effect until the
  // tour ends and a new one starts (which recreates the overlay from
  // scratch). Patch the current overlay's style directly here instead, so
  // it takes effect immediately -- exactly what a fresh creation would
  // have set. `getState()` (unlike the config store) is per-Driver-
  // instance, so this only ever touches `id`'s own overlay.
  const overlaySvg = drivers[id].getState("__overlaySvg");
  const overlayPath = overlaySvg && overlaySvg.firstElementChild;
  if (overlayPath) {
    if (typeof merged.overlayColor === "string") {
      overlayPath.style.fill = merged.overlayColor;
    }
    if (typeof merged.overlayOpacity !== "undefined") {
      overlayPath.style.opacity = String(merged.overlayOpacity);
    }
  }
});
// --- WP4 end ---

Shiny.addCustomMessageHandler("cicerone-start", function (opts) {
  const id = opts.id;
  if (!drivers[id]) return console.warn("cicerone: no tour", id);
  // --- async-safety begin ---
  // every start attempt is its own generation: a wait_for_visible poll
  // scheduled by an earlier, now-superseded attempt (below, or from a
  // Next/Previous click) must not act once this one has begun (see the
  // `navGen` note in bridge.js)
  bumpNavGen(id);
  // --- async-safety end ---
  const driver = drivers[id];
  let config = driver.getConfig();

  // --- WP5 begin: run_once persisted-completed suppression + resume ---
  // Placed before anything else in this handler (including WP7's
  // exclusive/wait_for_visible logic below): a suppressed start must
  // never destroy another tour or touch the DOM at all.
  if (isRunOnceCompleted(id)) {
    const record = persistRecords[id];
    const totalSteps = (config.steps || []).length;
    const index = record && typeof record.idx === "number" ? record.idx : null;
    emitInput(id, "ended", {
      reason: "suppressed",
      completed: false,
      index: index,
      total_steps: totalSteps,
    });
    emitEvent(id, "ended", { index: index, total_steps: totalSteps });
    return;
  }
  if (opts.resume) {
    const idx = resumeIndex(id);
    if (typeof idx === "number") opts.step = idx;
  }
  // --- WP5 end ---

  // --- WP7 begin: exclusive ---
  // `exclusive` defaults to TRUE R-side (see build_config()); anything
  // other than an explicit `false` here keeps that default even if the
  // key were ever absent from config.
  if (config.exclusive !== false) {
    Object.keys(drivers).forEach((otherId) => {
      const other = drivers[otherId];
      if (otherId !== id && other && other.isActive()) {
        // async-safety: invalidate any wait_for_visible poll still in
        // flight for the tour being superseded (see the `navGen` note
        // in bridge.js)
        bumpNavGen(otherId);
        pendingReason[otherId] = "superseded";
        other.destroy();
      }
    });
  }
  // --- WP7 end ---

  // --- WP4 begin: show_if filtering ---
  // Evaluate every step's `show_if` predicate against the FULL prepared
  // list (`allSteps[id]`, not `config.steps` -- a previous drive() may
  // have already narrowed `config.steps` to a filtered subset, and
  // filtering an already-filtered list would compound instead of
  // re-evaluate fresh), then push the result through `setSteps()` so
  // driver.js only ever drives the visible steps. `setSteps()` preserves
  // every other config key (it internally calls `setConfig({
  // ...getConfig(), steps})`, see the cicerone-set-config comment above),
  // so it is safe to call unconditionally here, including for a tour
  // with no `show_if` steps at all (filtered === full in that case).
  //
  // The requested 0-based index (against the FULL list) is mapped to its
  // position in the filtered list: a filtered-out requested step starts
  // at the next visible one after it (by original position). If none of
  // the full list is visible from the requested index onward, no tour is
  // driven; `no_visible_steps` is emitted instead. Restored to the full
  // list in the wrapped `onDestroyed` (steps.js's prepareConfig) so the
  // next `$start()` re-evaluates every predicate fresh (e.g. against a
  // checkbox that changed since the last run).
  const full = allSteps[id] || config.steps || [];
  const requestedIndex = typeof opts.step === "number" ? opts.step : 0;
  const filtered = [];
  const originalIndexes = [];
  full.forEach((step, i) => {
    let visible = true;
    if (typeof step.showIf === "function") {
      try {
        visible = !!step.showIf(step, { config, driver, index: i });
      } catch (e) {
        visible = true;
        console.warn("cicerone: show_if predicate threw; showing step", i, e);
      }
    }
    if (visible) {
      filtered.push(step);
      originalIndexes.push(i);
    }
  });

  driver.setSteps(filtered);
  config = driver.getConfig();

  if (filtered.length === 0) {
    emitEvent(id, "no_visible_steps", {
      index: null,
      highlighted: null,
      total_steps: 0,
    });
    return;
  }

  let mappedIndex = originalIndexes.findIndex((orig) => orig >= requestedIndex);
  if (mappedIndex === -1) mappedIndex = filtered.length - 1;
  opts.step = mappedIndex;
  // --- WP4 end ---

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
    // async-safety: captured now (see the `navGen` note in bridge.js) --
    // this start attempt already bumped its own generation above, so a
    // reset/restart/destroy-all that happens before this wait resolves
    // is what would move the generation on, not this line
    const gen = currentNavGen(id);
    waitForVisible(targetStep.element, { timeout: waitMs, requireVisible: true }).then(
      (result) => {
        // stale: something else (reset, destroy_all, a newer start, an
        // exclusive supersede) has already happened for this id -- do
        // not emit anchor_timeout and do not drive a tour that is no
        // longer this attempt's to drive
        if (currentNavGen(id) !== gen) return;
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
      // async-safety: see the `navGen` note in bridge.js
      bumpNavGen(id);
      pendingReason[id] = "programmatic";
      driver.destroy();
    }
  });
});
// --- WP7 end ---

// --- WP5 begin: cicerone-forget / cicerone-persist-record ---
// R -> JS push of an adapter-read record: sent right after
// `cicerone-init` from `$init()` (once `persist$read()` resolves), and
// available for any later push the same shape would need.
Shiny.addCustomMessageHandler("cicerone-persist-record", function (opts) {
  setPushedRecord(opts.id, opts.record);
  emitInput(opts.id, "seen", opts.record || null);
});

// `$forget()`: clear the JS-side cache (and, for the cookie backend,
// the cookie entry itself -- forgetPersisted() checks persistMode
// itself). The adapter backend's `forget(id)` callback runs
// server-side, in R/steps.R's `$forget()`, not here.
Shiny.addCustomMessageHandler("cicerone-forget", function (opts) {
  forgetPersisted(opts.id);
  emitInput(opts.id, "seen", null);
});
// --- WP5 end ---

Shiny.addCustomMessageHandler("cicerone-reset", function (opts) {
  if (!drivers[opts.id]) return;
  // async-safety: see the `navGen` note in bridge.js -- bumped even
  // though `destroy()` below may be a no-op (e.g. resetting a tour still
  // waiting on its very first `wait_for_visible`, before any step was
  // ever actively highlighted, never invokes the wrapped `onDestroyed`)
  bumpNavGen(opts.id);
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
