// Shared, side-effect-free helpers used across the cicerone bridge.

// Evaluate a string of JavaScript into a function
export const evalFunction = (body) => {
  if (typeof body !== "string") return body;
  return new Function("return " + body)();
};

export const evalHooks = (obj, hooks) => {
  if (!obj) return;
  hooks.forEach((hook) => {
    if (typeof obj[hook] === "string") {
      obj[hook] = evalFunction(obj[hook]);
    }
  });
};

// Turn "#id" into "id"; anything that is not a string selector returns null
export const stripHash = (el) => {
  if (typeof el === "string") return el.replace(/^#/, "");
  return null;
};

// Workaround for a driver.js 1.8.0 bug: with animate: true, advancing
// before the ~400ms transition completes leaks `driver-active-element`
// on the mid-animation element. driver.js reads the element to clean up
// from state that a superseded transition never commits (its callback
// self-terminates via the __transitionCallback guard). Since the class
// grants pointer-events: auto, every leaked element stays clickable
// under the overlay. Strip stale tags at every highlight start; driver
// re-tags the current element right after.
export const cleanupStaleHighlights = () => {
  document.querySelectorAll(".driver-active-element").forEach((el) => {
    el.classList.remove("driver-active-element", "driver-no-interaction");
    el.removeAttribute("aria-haspopup");
    el.removeAttribute("aria-expanded");
    el.removeAttribute("aria-controls");
  });
};

// Activate a Shiny tabset before highlighting an element in it
export const makeTabActivator = (tabId, tab) => {
  return () => {
    const tabs = $("#" + tabId);
    Shiny.inputBindings.bindingNames["shiny.bootstrapTabInput"].binding.setValue(
      tabs,
      tab,
    );
  };
};
