.pragma library

// Pure helpers shared by the island and its panel widgets. Kept free of QML
// types so they can be exercised by tests/islandutils.test.mjs under node.

// Grid bounds. MAX_ROWS is a guard against a corrupted config string, not a
// layout limit: rows grow on demand.
var MAX_COLS = 4;
var MAX_ROWS = 64;

// Parses an explicit col/row field. Anything non-numeric or out of range becomes
// -1, which means "place this widget automatically".
function parseCell(field, maxValue) {
    var v = parseInt(String(field).trim(), 10);
    if (isNaN(v) || v < 0 || v > maxValue) {
        return -1;
    }
    return v;
}

// Substitutes {token} placeholders from `vals`.
function formatTemplate(tpl, vals) {
    if (!tpl) {
        return "";
    }
    var source = vals || {};
    return String(tpl).replace(/\{(\w+)\}/g, function (match, key) {
        if (!Object.prototype.hasOwnProperty.call(source, key)) {
            return match;
        }
        var value = source[key];
        return (value === undefined || value === null) ? "" : String(value);
    });
}

// Legacy helper for simple id lists
function parseWidgetList(str, validIds) {
    var out = [];
    var allowed = validIds || [];
    var parts = String(str === null || str === undefined ? "" : str).split(",");
    for (var i = 0; i < parts.length; i++) {
        var raw = parts[i].trim();
        var id = raw.split(":")[0].trim();
        if (id.length === 0 || (allowed.length > 0 && allowed.indexOf(id) === -1) || out.indexOf(id) !== -1) {
            continue;
        }
        out.push(id);
    }
    return out;
}

function serializeWidgetList(ids) {
    return (ids || []).join(",");
}

// Parses grid items formatted as "id:col:row:spanW:spanH". Shorter forms are
// legacy ("id:spanW:spanH", "id:spanW", "id") and yield col/row -1, meaning the
// placement engine positions them. Field count is a safe discriminator because
// serializeWidgetSpecs only ever emits five fields.
function parseWidgetSpecs(str, validIds, defaultWFn, defaultHFn) {
    var out = [];
    var allowed = validIds || [];
    var seen = [];
    var parts = String(str === null || str === undefined ? "" : str).split(",");

    for (var i = 0; i < parts.length; i++) {
        var raw = parts[i].trim();
        if (raw.length === 0) continue;
        var pair = raw.split(":");
        var id = pair[0].trim();
        if (id.length === 0 || (allowed.length > 0 && allowed.indexOf(id) === -1) || seen.indexOf(id) !== -1) {
            continue;
        }

        var col = -1;
        var row = -1;
        var wField = 1;
        var hField = 2;
        var spanW = 3;
        var spanH = 1;

        if (pair.length >= 5) {
            col = parseCell(pair[1], MAX_COLS - 1);
            row = parseCell(pair[2], MAX_ROWS - 1);
            wField = 3;
            hField = 4;
        }

        if (pair.length > wField) {
            var parsedW = parseInt(pair[wField].trim(), 10);
            if (parsedW >= 1 && parsedW <= MAX_COLS) spanW = parsedW;
        } else if (defaultWFn) {
            spanW = typeof defaultWFn === "function" ? defaultWFn(id) : (defaultWFn[id] || 3);
        }

        if (pair.length > hField) {
            var parsedH = parseInt(pair[hField].trim(), 10);
            if (parsedH >= 1 && parsedH <= 3) spanH = parsedH;
        } else if (defaultHFn) {
            spanH = typeof defaultHFn === "function" ? defaultHFn(id) : (defaultHFn[id] || 1);
        }

        seen.push(id);
        out.push({ id: id, col: col, row: row, spanW: spanW, spanH: spanH });
    }
    return out;
}

// Always emits five fields, which is what makes field count a safe format
// discriminator on the way back in.
function serializeWidgetSpecs(specs) {
    if (!specs || !specs.length) return "";
    var parts = [];
    for (var i = 0; i < specs.length; i++) {
        var item = specs[i];
        if (typeof item === "string") {
            parts.push(item);
        } else if (item && item.id) {
            var col = (item.col === undefined || item.col === null) ? -1 : item.col;
            var row = (item.row === undefined || item.row === null) ? -1 : item.row;
            parts.push(item.id + ":" + col + ":" + row + ":" + (item.spanW || 3) + ":" + (item.spanH || 1));
        }
    }
    return parts.join(",");
}

function cycleSpan2D(w, h, maxCols) {
    var spanW = parseInt(w, 10) || 1;
    var spanH = parseInt(h, 10) || 1;
    var maxC = parseInt(maxCols, 10) || 3;

    var nextW = spanW;
    var nextH = spanH;

    if (spanW === 1 && spanH === 1) {
        nextW = 2; nextH = 1;
    } else if (spanW === 2 && spanH === 1) {
        nextW = 2; nextH = 2;
    } else if (spanW === 2 && spanH === 2) {
        nextW = 3; nextH = 1;
    } else if (spanW === 3 && spanH === 1) {
        nextW = 3; nextH = 2;
    } else if (spanW === 3 && spanH === 2 && maxC >= 4) {
        nextW = 4; nextH = 1;
    } else if (spanW === 4 && spanH === 1) {
        nextW = 4; nextH = 2;
    } else if (spanW === 4 && spanH === 2) {
        nextW = 4; nextH = 3;
    } else {
        nextW = 1; nextH = 1;
    }

    if (nextW > maxC) {
        return { spanW: 1, spanH: 1 };
    }
    return { spanW: nextW, spanH: nextH };
}

// Formats a duration as mm:ss, widening to h:mm:ss past an hour.
function mmss(seconds) {
    var total = Math.max(0, Math.floor(seconds || 0));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    var pad = function (n) {
        return n < 10 ? "0" + n : String(n);
    };
    if (hours > 0) {
        return hours + ":" + pad(minutes) + ":" + pad(secs);
    }
    return pad(minutes) + ":" + pad(secs);
}

// Moves one element, returning a new array.
function moveItem(arr, from, to) {
    var out = (arr || []).slice();
    if (from < 0 || from >= out.length) {
        return out;
    }
    var target = Math.max(0, Math.min(out.length - 1, to));
    if (target === from) {
        return out;
    }
    out.splice(target, 0, out.splice(from, 1)[0]);
    return out;
}
