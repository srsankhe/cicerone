// WP5: tour persistence, JS side.
//
// A leaf module: no import of bridge.js/tour.js, and no Shiny dependency
// either (mirrors anchor.js's own leaf-module shape). It owns:
// - the cookie codec (one cookie named "cicerone", a URL-encoded JSON
//   object keyed by tour id, rewritten whole on every write);
// - the per-id registries (`persistMode`, `persistVersion`,
//   `runOnceFlags`, `persistRecords`) tour.js's WP5 regions read/write;
// - the record-shape bookkeeping (`recordOnStarted`/`recordOnHighlighted`/
//   `recordOnEnded`), used only for the cookie backend -- the adapter
//   backend does the equivalent bookkeeping server-side (R/steps.R's
//   `register_persist_observers()`), from the same `_started`/`_state`/
//   `_ended` inputs tour.js already emits.
//
// Record shape (identical for both backends): {v, status, idx, n, t} --
// see `?Cicerone`'s Persistence section for the field meanings.

const COOKIE_NAME = "cicerone";

// id -> "cookie" | "adapter" | null (unset means no persistence)
export let persistMode = {};
// id -> the tour's configured `version`
export let persistVersion = {};
// id -> whether `$init(run_once = TRUE)` was requested
export let runOnceFlags = {};
// id -> last known record (or null), for either backend -- the adapter
// backend's copy arrives via `cicerone-persist-record`, pushed from R
export let persistRecords = {};

let warnedCookieFailure = false;
const warnCookieFailure = (err) => {
  if (warnedCookieFailure) return;
  warnedCookieFailure = true;
  console.warn(
    "cicerone: persistence via cookie failed, continuing without it", err,
  );
};

const nowIso = () => new Date().toISOString();

// Read the whole `cicerone` cookie as a {tourId: record} map. Never
// throws: any failure (a cookie API that is unavailable, e.g. in a
// sandboxed iframe, or a value that fails to decode/parse) is reported
// once via `console.warn` and treated as "no persisted tours at all".
const readCookieMap = () => {
  try {
    const match = document.cookie.match(/(?:^|;\s*)cicerone=([^;]*)/);
    if (!match) return {};
    const parsed = JSON.parse(decodeURIComponent(match[1]));
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (err) {
    warnCookieFailure(err);
    return {};
  }
};

// Rewrite the whole `cicerone` cookie from a {tourId: record} map.
// `path=/; SameSite=Lax; max-age=31536000` (one year), plus `Secure`
// when the page itself is served over https.
const writeCookieMap = (map) => {
  try {
    const value = encodeURIComponent(JSON.stringify(map));
    const secure = location.protocol === "https:" ? "; Secure" : "";
    document.cookie =
      COOKIE_NAME + "=" + value +
      "; path=/; SameSite=Lax; max-age=31536000" + secure;
  } catch (err) {
    warnCookieFailure(err);
  }
};

// Read one tour's record out of the cookie, honouring `version`: a
// stored record whose `v` does not match reads as "no record" (cicerone
// does not migrate old records).
const readCookieRecord = (id, version) => {
  const record = readCookieMap()[id];
  if (!record || record.v !== version) return null;
  return record;
};

const writeCookieRecord = (id, record) => {
  const map = readCookieMap();
  map[id] = record;
  writeCookieMap(map);
};

const forgetCookieRecord = (id) => {
  const map = readCookieMap();
  delete map[id];
  writeCookieMap(map);
};

// Register a tour's persistence setup at `cicerone-init` time. Returns
// the record to use immediately (cookie backend only -- the adapter
// backend's record arrives a moment later via `cicerone-persist-record`,
// pushed from R once `$init()`'s `persist$read()` resolves).
export const initPersistence = (id, mode, version, runOnce) => {
  persistMode[id] = mode || null;
  persistVersion[id] = version;
  runOnceFlags[id] = !!runOnce;

  if (persistMode[id] === "cookie") {
    persistRecords[id] = readCookieRecord(id, version);
  } else {
    persistRecords[id] = null;
  }

  return persistRecords[id];
};

// `cicerone-persist-record`: R pushes an adapter-read record (at
// `$init()`, after `persist$read()` resolves).
export const setPushedRecord = (id, record) => {
  persistRecords[id] = record || null;
};

// `run_once` + already-completed check for `cicerone-start`.
export const isRunOnceCompleted = (id) => {
  const record = persistRecords[id];
  return !!(runOnceFlags[id] && record && record.status === "completed");
};

// `resume = TRUE`: the index to start at, or null when there is nothing
// to resume (no record, or the tour was already completed/dismissed
// rather than left in progress).
export const resumeIndex = (id) => {
  const record = persistRecords[id];
  if (record && record.status === "in_progress" && typeof record.idx === "number")
    return record.idx;
  return null;
};

// Write points. All four no-op outside the cookie backend: the adapter
// backend's equivalent bookkeeping happens server-side, off the same
// `_started`/`_state`/`_ended` inputs (see R/steps.R).
export const recordOnStarted = (id, index) => {
  if (persistMode[id] !== "cookie") return;
  const prev = persistRecords[id];
  const record = {
    v: persistVersion[id],
    status: "in_progress",
    idx: index,
    n: (prev && typeof prev.n === "number" ? prev.n : 0) + 1,
    t: nowIso(),
  };
  persistRecords[id] = record;
  writeCookieRecord(id, record);
};

export const recordOnHighlighted = (id, index) => {
  if (persistMode[id] !== "cookie") return;
  const prev = persistRecords[id] || { v: persistVersion[id], status: "in_progress", n: 1 };
  const record = Object.assign({}, prev, { idx: index, t: nowIso() });
  persistRecords[id] = record;
  writeCookieRecord(id, record);
};

export const recordOnEnded = (id, reason, index) => {
  if (persistMode[id] !== "cookie") return;
  const prev = persistRecords[id] || { v: persistVersion[id], status: "in_progress", n: 1 };
  const record = Object.assign({}, prev, {
    status: reason === "done" ? "completed" : "dismissed",
    idx: typeof index === "number" ? index : prev.idx,
    t: nowIso(),
  });
  persistRecords[id] = record;
  writeCookieRecord(id, record);
};

// `$forget()`/`cicerone-forget`: clear the JS-side cache and, for the
// cookie backend, the cookie entry itself. The adapter backend's
// `forget(id)` callback runs server-side (R/steps.R's `$forget()`), not
// here.
export const forgetPersisted = (id) => {
  persistRecords[id] = null;
  if (persistMode[id] === "cookie") forgetCookieRecord(id);
};
