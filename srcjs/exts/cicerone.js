import "shiny";
import "jquery";
import { driver as Driver } from "driver.js";
import { hints as Hints } from "driver.js/hints";
import "driver.js/dist/driver.css";
import "driver.js/dist/hints.css";
import "./custom.css";

import { drivers, hinters } from "./bridge.js";
// --- WP6 begin ---
import { advanceListeners } from "./advance.js";
// --- WP6 end ---

// Host applications sometimes have to drive a tour from their own JavaScript,
// when the signals it must react to are only observable in the DOM and never
// reach Shiny. cicerone 1.0.4 shipped as a classic script, so its top-level
// `var driver = []` leaked onto window and host code relied on that; the packer
// build scopes it to this module. Publish it deliberately instead, so the
// integration point is a stated API rather than an accident of bundling.
window.cicerone = {
  drivers: drivers,
  hints: hinters,
  // --- WP6 begin ---
  advanceListeners: advanceListeners,
  // --- WP6 end ---
};

import "./tour.js";
import "./hints.js";
// --- WP7 begin: standalone wait_for_element() handler ---
import "./anchor.js";
// --- WP7 end ---
