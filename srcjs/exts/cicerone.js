import "shiny";
import "jquery";
import { driver as Driver } from "driver.js";
import { hints as Hints } from "driver.js/hints";
import "driver.js/dist/driver.css";
import "driver.js/dist/hints.css";
import "./custom.css";

// driver.js 1.x instances, keyed by cicerone id
let drivers = {};
// hints instances, keyed by cicerone id
let hinters = {};

// Host applications sometimes have to drive a tour from their own JavaScript,
// when the signals it must react to are only observable in the DOM and never
// reach Shiny. cicerone 1.0.4 shipped as a classic script, so its top-level
// `var driver = []` leaked onto window and host code relied on that; the packer
// build scopes it to this module. Publish it deliberately instead, so the
// integration point is a stated API rather than an accident of bundling.
window.cicerone = { drivers: drivers, hints: hinters };

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

// Evaluate a string of JavaScript into a function
const evalFunction = (body) => {
  if (typeof body !== "string") return body;
  return new Function("return " + body)();
};

const evalHooks = (obj, hooks) => {
  if (!obj) return;
  hooks.forEach((hook) => {
    if (typeof obj[hook] === "string") {
      obj[hook] = evalFunction(obj[hook]);
    }
  });
};

// Turn "#id" into "id"; anything that is not a string selector returns null
const stripHash = (el) => {
  if (typeof el === "string") return el.replace(/^#/, "");
  return null;
};

// Snapshot of the driver state sent to Shiny.
// `highlighted`, `previous`, `before_previous` and `has_next` are kept
// for backwards compatibility with cicerone < 2.0.0.
const getStateData = (d) => {
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

// Wrap a user supplied onNextClick so that:
// 1. the `{id}_cicerone_next` Shiny input always fires
// 2. the tour still advances (driver.js 1.x hands control over
//    when onNextClick is overridden) unless the user callback
//    explicitly returns `false`
const wrapNext = (id, fn) => {
  return (element, step, opts) => {
    Shiny.setInputValue(id + "_cicerone_next", getStateData(drivers[id]), {
      priority: "event",
    });
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].moveNext();
  };
};

const wrapPrevious = (id, fn) => {
  return (element, step, opts) => {
    Shiny.setInputValue(id + "_cicerone_previous", getStateData(drivers[id]), {
      priority: "event",
    });
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].movePrevious();
  };
};

// Activate a Shiny tabset before highlighting an element in it
const makeTabActivator = (tabId, tab) => {
  return () => {
    const tabs = $("#" + tabId);
    Shiny.inputBindings.bindingNames["shiny.bootstrapTabInput"].binding.setValue(
      tabs,
      tab,
    );
  };
};

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

  // always notify Shiny of state when a step is highlighted
  const userHighlighted = config.onHighlighted;
  config.onHighlighted = (element, step, hookOpts) => {
    if (userHighlighted) userHighlighted(element, step, hookOpts);
    Shiny.setInputValue(id + "_cicerone_state", getStateData(drivers[id]));
  };

  // always notify Shiny when next/previous is clicked
  config.onNextClick = wrapNext(id, config.onNextClick);
  config.onPrevClick = wrapPrevious(id, config.onPrevClick);

  // always notify Shiny when the tour is closed/destroyed
  const userDestroyed = config.onDestroyed;
  config.onDestroyed = (element, step, hookOpts) => {
    if (userDestroyed) userDestroyed(element, step, hookOpts);
    Shiny.setInputValue("cicerone_reset", true, { priority: "event" });
    Shiny.setInputValue(id + "_cicerone_reset", true, { priority: "event" });
  };

  const steps = opts.steps || [];
  steps.forEach((step) => {
    // activate tab before highlighting, composing with any user hook
    if (step.tab_id && step.tab) {
      const activateTab = makeTabActivator(step.tab_id, step.tab);
      const userStart = evalFunction(step.onHighlightStarted);
      step.onHighlightStarted = (element, s, hookOpts) => {
        activateTab();
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
  if (!drivers[id]) drivers[id] = Driver({});
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

/* ------------------------------- hints ------------------------------- */

const HINT_HOOKS = ["onOpen", "onDismiss", "onButtonClick"];

Shiny.addCustomMessageHandler("cicerone-hints-init", function (opts) {
  const id = opts.id;
  const config = opts.config || {};

  evalHooks(config, HINT_HOOKS);

  // notify Shiny when hints are opened/dismissed/clicked
  const userOpen = config.onOpen;
  config.onOpen = (element, hint, hookOpts) => {
    if (userOpen) userOpen(element, hint, hookOpts);
    Shiny.setInputValue(
      id + "_cicerone_hint_opened",
      { id: hint.id || null, element: stripHash(hint.element) },
      { priority: "event" },
    );
  };

  const userDismiss = config.onDismiss;
  config.onDismiss = (element, hint, hookOpts) => {
    if (userDismiss) userDismiss(element, hint, hookOpts);
    Shiny.setInputValue(
      id + "_cicerone_hint_dismissed",
      { id: hint.id || null, element: stripHash(hint.element) },
      { priority: "event" },
    );
  };

  const userButton = config.onButtonClick;
  config.onButtonClick = (element, hint, hookOpts) => {
    if (userButton) userButton(element, hint, hookOpts);
    Shiny.setInputValue(
      id + "_cicerone_hint_button",
      { id: hint.id || null, element: stripHash(hint.element) },
      { priority: "event" },
    );
  };

  (opts.hints || []).forEach((hint) => {
    evalHooks(hint, ["onOpen", "onDismiss"]);
    if (hint.popover) {
      evalHooks(hint.popover, ["onButtonClick", "onPopoverRender"]);
    }
  });

  config.hints = opts.hints || [];
  hinters[id] = Hints(config);
});

Shiny.addCustomMessageHandler("cicerone-hints-show", function (opts) {
  if (!hinters[opts.id]) return console.warn("cicerone: no hints", opts.id);
  hinters[opts.id].show();
});

Shiny.addCustomMessageHandler("cicerone-hints-hide", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].hide();
});

Shiny.addCustomMessageHandler("cicerone-hints-open", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].open(opts.hint);
});

Shiny.addCustomMessageHandler("cicerone-hints-close", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].close();
});

Shiny.addCustomMessageHandler("cicerone-hints-dismiss", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].dismiss(opts.hint);
});

Shiny.addCustomMessageHandler("cicerone-hints-restore", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].restore(opts.hint);
});

Shiny.addCustomMessageHandler("cicerone-hints-refresh", function (opts) {
  if (!hinters[opts.id]) return;
  hinters[opts.id].refresh();
});
