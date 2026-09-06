// The Shiny <-> driver.js bridge: instance registries and the wrappers
// that keep Shiny inputs in sync with tour state.
import { stripHash } from "./util.js";

// driver.js 1.x instances, keyed by cicerone id
export let drivers = {};
// hints instances, keyed by cicerone id
export let hinters = {};

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

// Wrap a user supplied onNextClick so that:
// 1. the `{id}_cicerone_next` Shiny input always fires
// 2. the tour still advances (driver.js 1.x hands control over
//    when onNextClick is overridden) unless the user callback
//    explicitly returns `false`
export const wrapNext = (id, fn) => {
  return (element, step, opts) => {
    emitInput(id, "next", getStateData(drivers[id]));
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].moveNext();
  };
};

export const wrapPrevious = (id, fn) => {
  return (element, step, opts) => {
    emitInput(id, "previous", getStateData(drivers[id]));
    let out;
    if (fn) out = fn(element, step, opts);
    if (out !== false && drivers[id]) drivers[id].movePrevious();
  };
};
