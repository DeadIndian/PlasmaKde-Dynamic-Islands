.pragma library

// Pure helpers shared by the island and its panel widgets. Kept free of QML
// types so they can be exercised by tests/islandutils.test.mjs under node.

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

// Parses grid items formatted as "id:spanW:spanH", "id:spanW", or "id".
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
        var spanW = 3;
        var spanH = 1;

        if (pair.length > 1) {
            var parsedW = parseInt(pair[1].trim(), 10);
            if (parsedW >= 1 && parsedW <= 4) spanW = parsedW;
        } else if (defaultWFn) {
            spanW = typeof defaultWFn === "function" ? defaultWFn(id) : (defaultWFn[id] || 3);
        }

        if (pair.length > 2) {
            var parsedH = parseInt(pair[2].trim(), 10);
            if (parsedH >= 1 && parsedH <= 3) spanH = parsedH;
        } else if (defaultHFn) {
            spanH = typeof defaultHFn === "function" ? defaultHFn(id) : (defaultHFn[id] || 1);
        }

        seen.push(id);
        out.push({ id: id, spanW: spanW, spanH: spanH });
    }
    return out;
}

function serializeWidgetSpecs(specs) {
    if (!specs || !specs.length) return "";
    var parts = [];
    for (var i = 0; i < specs.length; i++) {
        var item = specs[i];
        if (typeof item === "string") {
            parts.push(item);
        } else if (item && item.id) {
            parts.push(item.id + ":" + (item.spanW || 3) + ":" + (item.spanH || 1));
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
