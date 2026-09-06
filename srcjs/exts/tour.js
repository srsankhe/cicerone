// Tour lifecycle: every `cicerone-*` Shiny custom message handler.
import { driver as Driver } from "driver.js";
import {
  drivers,
  getStateData,
  wrapNext,
  wrapPrevious,
  emitInput,
} from "./bridge.js";
import {
  evalFunction,
  evalHooks,
  cleanupStaleHighlights,
  makeTabActivator,
} from "./util.js";

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

  // string hooks -> functions
  evalHooks(config, CONFIG_HOOKS);
  if (
    typeof config.overlayClickBehavior === "string" &&
    !["close", "nextStep"].includes(config.overlayClickBehavior)
  ) {
    config.overlayClickBehavior = evalFunction(config.overlayClickBehavior);
  }

  // strip leaked driver-active-element tags on every transfer;
  // note: a step-level onHighlightStarted overrides this hook, so the
  // step loop below re-injects the cleanup there
  const userHighlightStarted = config.onHighlightStarted;
  config.onHighlightStarted = (element, step, hookOpts) => {
    cleanupStaleHighlights();
    if (userHighlightStarted) userHighlightStarted(element, step, hookOpts);
  };

  // always notify Shiny of state when a step is highlighted
  const userHighlighted = config.onHighlighted;
  config.onHighlighted = (element, step, hookOpts) => {
    if (userHighlighted) userHighlighted(element, step, hookOpts);
    emitInput(id, "state", getStateData(drivers[id]), false);
  };

  // always notify Shiny when next/previous is clicked
  config.onNextClick = wrapNext(id, config.onNextClick);
  config.onPrevClick = wrapPrevious(id, config.onPrevClick);

  // always notify Shiny when the tour is closed/destroyed
  const userDestroyed = config.onDestroyed;
  config.onDestroyed = (element, step, hookOpts) => {
    if (userDestroyed) userDestroyed(element, step, hookOpts);
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

    if (step.popover) {
      evalHooks(step.popover, POPOVER_HOOKS);
      if (step.popover.onNextClick) {
        step.popover.onNextClick = wrapNext(
          id,
          evalFunction(step.popover.onNextClick),
        );
      }
      if (step.popover.onPrevClick) {
        step.popover.onPrevClick = wrapPrevious(
          id,
          evalFunction(step.popover.onPrevClick),
        );
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
  drivers[opts.id].destroy();
});

Shiny.addCustomMessageHandler("cicerone-next", function (opts) {
  if (!drivers[opts.id]) return;
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
  drivers[id].highlight(opts);
});
