// WP7: element-readiness polling.
//
// Two consumers:
// 1. The standalone `cicerone-wait-element` handler below, for
//    `wait_for_element()` -- works with no tour initialised, this module
//    never touches `drivers`/`hinters`.
// 2. `waitForVisible()`/`effectiveWaitForVisible()`/
//    `effectiveSkipMissingElement()`, imported by `bridge.js` (wrapNext/
//    wrapPrevious) and `tour.js` (cicerone-start) to gate a step move on
//    `wait_for_visible`.
//
// This module is a leaf: it does not import from bridge.js/tour.js, so
// there is no import cycle with the modules that import from it.

// {width, height} of an element's current bounding rect, or null.
const rectOf = (el) => {
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { width: r.width, height: r.height };
};

export const isVisible = (el) => {
  const r = rectOf(el);
  return !!r && r.width > 0 && r.height > 0;
};

// Resolve once `selector` matches an element -- and, when `requireVisible`
// (default `true`), once that element has a non-zero bounding rect -- or
// once `timeout` ms elapse, whichever comes first. Never rejects; always
// resolves `{found, visible, elapsed}`.
//
// Watches for readiness with a `MutationObserver` on `document.documentElement`
// (matching driver.js's own `waitForElement` observer options), plus a
// `ResizeObserver` on the matched element once found but not yet visible, for
// layout-driven size changes that are not themselves a DOM mutation. Falls
// back to the `MutationObserver` alone when `ResizeObserver` is unavailable.
export const waitForVisible = (selector, opts = {}) => {
  const timeout = opts.timeout > 0 ? opts.timeout : 0;
  const requireVisible = opts.requireVisible !== false;
  const start = Date.now();

  return new Promise((resolve) => {
    let settled = false;
    let resizeObserver = null;
    let observedEl = null;

    const finish = (found, visible) => {
      if (settled) return;
      settled = true;
      mutationObserver.disconnect();
      if (resizeObserver) resizeObserver.disconnect();
      window.clearTimeout(timer);
      resolve({ found: found, visible: visible, elapsed: Date.now() - start });
    };

    const check = () => {
      const el = document.querySelector(selector);
      if (!el) return false;
      const visible = isVisible(el);
      if (!requireVisible || visible) {
        finish(true, visible);
        return true;
      }
      if (el !== observedEl && typeof ResizeObserver !== "undefined") {
        if (resizeObserver) resizeObserver.disconnect();
        observedEl = el;
        resizeObserver = new ResizeObserver(check);
        resizeObserver.observe(el);
      }
      return false;
    };

    const mutationObserver = new MutationObserver(check);
    const timer = window.setTimeout(() => {
      const el = document.querySelector(selector);
      finish(!!el, !!el && isVisible(el));
    }, timeout);

    if (check()) return;

    mutationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
    });
  });
};

// Effective `waitForVisible` (ms) for a step: step-level overrides
// config-level. Anything that is not a positive number means "disabled".
export const effectiveWaitForVisible = (step, config) => {
  const stepVal = step && step.waitForVisible;
  const val = typeof stepVal === "number" ? stepVal : config && config.waitForVisible;
  return typeof val === "number" && val > 0 ? val : 0;
};

// Effective `skipMissingElement` for a step: step-level overrides
// config-level, same precedence driver.js itself uses (see `F()` in
// driver.js.mjs).
export const effectiveSkipMissingElement = (step, config) => {
  if (step && typeof step.skipMissingElement === "boolean") return step.skipMissingElement;
  return !!(config && config.skipMissingElement);
};

// Standalone helper: `wait_for_element()` has no `Cicerone`/tour behind it,
// so it is not routed through bridge.js's `emitInput()`; it sets the Shiny
// input directly, matching `emitInput()`'s own `{id}_cicerone_{suffix}`
// naming and event priority.
Shiny.addCustomMessageHandler("cicerone-wait-element", function (opts) {
  waitForVisible(opts.selector, {
    timeout: opts.timeout,
    requireVisible: opts.visible !== false,
  }).then((result) => {
    Shiny.setInputValue(
      opts.id + "_cicerone_anchor",
      {
        selector: opts.selector,
        found: result.found,
        visible: result.visible,
        elapsed: result.elapsed,
      },
      { priority: "event" },
    );
  });
});
