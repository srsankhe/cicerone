// Hints module: every `cicerone-hints-*` Shiny custom message handler.
import { hints as Hints } from "driver.js/hints";
import { hinters, emitInput, emitEvent } from "./bridge.js";
import { evalHooks, stripHash } from "./util.js";

const HINT_HOOKS = ["onOpen", "onDismiss", "onButtonClick"];

Shiny.addCustomMessageHandler("cicerone-hints-init", function (opts) {
  const id = opts.id;
  const config = opts.config || {};
  const hintsList = opts.hints || [];
  const total = hintsList.length;

  evalHooks(config, HINT_HOOKS);

  // dismiss the hint the button belongs to, matching driver.js's default
  // click behaviour (`id` when the hint has one, else its 0-based index --
  // see `d()`/`dismiss()` in hints.mjs, which key hints the same way)
  const dismissHint = (hint, index) => {
    if (hinters[id]) hinters[id].dismiss(hint.id != null ? hint.id : index);
  };

  // Shared emission logic for onOpen/onDismiss, factored so both the
  // config-level wrap below AND a per-hint override (hint.onOpen/
  // hint.onDismiss, wrapped in the hintsList.forEach loop below) run the
  // exact same bookkeeping. driver.js resolves `hint.onOpen||config.onOpen`
  // and `hint.onDismiss||config.onDismiss` (see `F()`/`L()` in hints.mjs:
  // `(n.hint.onOpen||t.onOpen)?.(...)`, `(i.hint.onDismiss||t.onDismiss)?.(...)`)
  // -- hint-level, when present, is called INSTEAD of config-level, the
  // same last-one-defined-wins contract onButtonClick already has here.
  // Before this factoring, a hint's own on_open/on_dismiss was only
  // `evalHooks()`'d (string -> function) and never wrapped, so driver.js
  // called the user's raw hook directly and cicerone never saw the event.
  const wrapHintOpen = (userFn) => (element, hint, hookOpts) => {
    if (userFn) userFn(element, hint, hookOpts);
    const index = hintsList.indexOf(hint);
    const el = stripHash(hint.element);
    emitInput(id, "hint_opened", { id: hint.id || null, element: el });
    emitEvent(id, "hint_opened", {
      index: index,
      highlighted: el,
      total_steps: total,
    });
  };

  const wrapHintDismiss = (userFn) => (element, hint, hookOpts) => {
    if (userFn) userFn(element, hint, hookOpts);
    const index = hintsList.indexOf(hint);
    const el = stripHash(hint.element);
    emitInput(id, "hint_dismissed", { id: hint.id || null, element: el });
    emitEvent(id, "hint_dismissed", {
      index: index,
      highlighted: el,
      total_steps: total,
    });
  };

  // notify Shiny when hints are opened/dismissed (config-level fallback,
  // used for every hint that defines no on_open/on_dismiss of its own)
  config.onOpen = wrapHintOpen(config.onOpen);
  config.onDismiss = wrapHintDismiss(config.onDismiss);

  // a supplied onButtonClick replaces driver.js's default dismiss-on-click
  // (see `N()` in hints.mjs: `if(r) return r(...); L(e.id)` never reaches
  // the default dismiss once `r` -- config- or popover-level -- resolves
  // truthy). Always define config-level onButtonClick so that default is
  // restored: call the user hook if any, notify Shiny, then dismiss the
  // hint unless the hook returned `false`.
  const userButton = config.onButtonClick;
  config.onButtonClick = (element, hint, hookOpts) => {
    const index = hintsList.indexOf(hint);
    const el = stripHash(hint.element);
    let out;
    if (userButton) out = userButton(element, hint, hookOpts);
    emitInput(id, "hint_button", { id: hint.id || null, element: el });
    emitEvent(id, "hint_button", {
      index: index,
      highlighted: el,
      total_steps: total,
    });
    if (out !== false) dismissHint(hint, index);
  };

  hintsList.forEach((hint, index) => {
    evalHooks(hint, ["onOpen", "onDismiss"]);
    // a hint-level onOpen/onDismiss takes precedence over the config-level
    // wrap above (same resolver as `F()`/`L()` in hints.mjs), so it needs
    // the same emission wrap to keep Shiny in sync
    if (hint.onOpen) hint.onOpen = wrapHintOpen(hint.onOpen);
    if (hint.onDismiss) hint.onDismiss = wrapHintDismiss(hint.onDismiss);
    if (hint.popover) {
      evalHooks(hint.popover, ["onButtonClick", "onPopoverRender"]);
      // popover-level onButtonClick takes precedence over the config-level
      // wrapper above (same resolver as `N()` in hints.mjs), so it needs
      // the same dismiss-forwarding wrap to keep the default behaviour
      if (hint.popover.onButtonClick) {
        const userHintButton = hint.popover.onButtonClick;
        hint.popover.onButtonClick = (element, h, hookOpts) => {
          const el = stripHash(h.element);
          const out = userHintButton(element, h, hookOpts);
          emitInput(id, "hint_button", { id: h.id || null, element: el });
          emitEvent(id, "hint_button", {
            index: index,
            highlighted: el,
            total_steps: total,
          });
          if (out !== false) dismissHint(h, index);
        };
      }
    }
  });

  config.hints = hintsList;
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
