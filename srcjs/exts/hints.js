// Hints module: every `cicerone-hints-*` Shiny custom message handler.
import { hints as Hints } from "driver.js/hints";
import { hinters, emitInput } from "./bridge.js";
import { evalHooks, stripHash } from "./util.js";

const HINT_HOOKS = ["onOpen", "onDismiss", "onButtonClick"];

Shiny.addCustomMessageHandler("cicerone-hints-init", function (opts) {
  const id = opts.id;
  const config = opts.config || {};

  evalHooks(config, HINT_HOOKS);

  // notify Shiny when hints are opened/dismissed/clicked
  const userOpen = config.onOpen;
  config.onOpen = (element, hint, hookOpts) => {
    if (userOpen) userOpen(element, hint, hookOpts);
    emitInput(id, "hint_opened", {
      id: hint.id || null,
      element: stripHash(hint.element),
    });
  };

  const userDismiss = config.onDismiss;
  config.onDismiss = (element, hint, hookOpts) => {
    if (userDismiss) userDismiss(element, hint, hookOpts);
    emitInput(id, "hint_dismissed", {
      id: hint.id || null,
      element: stripHash(hint.element),
    });
  };

  const userButton = config.onButtonClick;
  config.onButtonClick = (element, hint, hookOpts) => {
    if (userButton) userButton(element, hint, hookOpts);
    emitInput(id, "hint_button", {
      id: hint.id || null,
      element: stripHash(hint.element),
    });
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
