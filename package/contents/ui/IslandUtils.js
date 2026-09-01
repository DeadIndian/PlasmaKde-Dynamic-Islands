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

// Maps every cell a widget covers to that widget's index. Sparse: occ[row][col].
// `skipIndex` leaves one widget out, which is how a drag asks "would this fit if
// the card I am holding were not there?".
function buildOccupancy(items, cols, skipIndex) {
    var occ = [];
    var list = items || [];
    var skip = (skipIndex === undefined || skipIndex === null) ? -1 : skipIndex;
    for (var i = 0; i < list.length; i++) {
        if (i === skip) continue;
        var it = list[i];
        if (!it || it.col < 0 || it.row < 0) continue;
        var w = Math.max(1, Math.min(cols, it.spanW || 1));
        var h = Math.max(1, it.spanH || 1);
        for (var dr = 0; dr < h; dr++) {
            var r = it.row + dr;
            if (!occ[r]) occ[r] = [];
            for (var dc = 0; dc < w; dc++) {
                occ[r][it.col + dc] = i;
            }
        }
    }
    return occ;
}

// True when a spanW x spanH block sits inside the grid at (col,row) without
// overlapping anything in `occ`.
function fits(occ, col, row, spanW, spanH, cols) {
    if (col < 0 || row < 0) return false;
    var w = Math.max(1, spanW || 1);
    var h = Math.max(1, spanH || 1);
    if (col + w > cols) return false;
    for (var dr = 0; dr < h; dr++) {
        var cells = occ[row + dr];
        if (!cells) continue;
        for (var dc = 0; dc < w; dc++) {
            if (cells[col + dc] !== undefined) return false;
        }
    }
    return true;
}

// First free slot in reading order. Rows grow on demand so this always finds
// somewhere; MAX_ROWS only stops a runaway loop on a corrupted grid.
function findFreeSlot(occ, spanW, spanH, cols) {
    var w = Math.max(1, Math.min(cols, spanW || 1));
    var h = Math.max(1, spanH || 1);
    for (var r = 0; r < MAX_ROWS; r++) {
        for (var c = 0; c <= cols - w; c++) {
            if (fits(occ, c, r, w, h, cols)) {
                return { col: c, row: r };
            }
        }
    }
    return { col: 0, row: 0 };
}

// Turns a list of widgets into a laid-out grid. Two passes: honour every explicit
// placement that still fits, sliding a widget left when its span no longer
// reaches the right edge; then auto-place whatever is left in reading order.
// Pure — the caller writes the returned values back to the model.
function resolvePlacements(items, cols) {
    var list = items || [];
    var out = [];
    var i;

    for (i = 0; i < list.length; i++) {
        var src = list[i] || {};
        out.push({
            id: src.id,
            col: (src.col === undefined || src.col === null) ? -1 : src.col,
            row: (src.row === undefined || src.row === null) ? -1 : src.row,
            spanW: Math.max(1, Math.min(cols, src.spanW || 1)),
            spanH: Math.max(1, src.spanH || 1)
        });
    }

    var occ = [];

    function mark(item, index) {
        for (var dr = 0; dr < item.spanH; dr++) {
            var r = item.row + dr;
            if (!occ[r]) occ[r] = [];
            for (var dc = 0; dc < item.spanW; dc++) {
                occ[r][item.col + dc] = index;
            }
        }
    }

    for (i = 0; i < out.length; i++) {
        var placed = out[i];
        if (placed.col < 0 || placed.row < 0) continue;
        var col = Math.max(0, Math.min(placed.col, cols - placed.spanW));
        if (fits(occ, col, placed.row, placed.spanW, placed.spanH, cols)) {
            placed.col = col;
            mark(placed, i);
        } else {
            placed.col = -1;
            placed.row = -1;
        }
    }

    for (i = 0; i < out.length; i++) {
        var loose = out[i];
        if (loose.col >= 0 && loose.row >= 0) continue;
        var slot = findFreeSlot(occ, loose.spanW, loose.spanH, cols);
        loose.col = slot.col;
        loose.row = slot.row;
        mark(loose, i);
    }

    var rows = 0;
    for (i = 0; i < out.length; i++) {
        var bottom = out[i].row + out[i].spanH;
        if (bottom > rows) rows = bottom;
    }

    return { items: out, rows: rows };
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
