.pragma library

// Pure helpers shared by the island and its panel widgets. Kept free of QML
// types so they can be exercised by tests/islandutils.test.mjs under node.

// Substitutes {token} placeholders from `vals`. An unrecognised token is left
// literal so a typo shows up in the UI instead of silently blanking the line.
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

// Reads the stored widget order. Unknown ids and duplicates are dropped so a
// hand-edited or downgraded config can never produce a broken panel.
function parseWidgetList(str, validIds) {
    var out = [];
    var allowed = validIds || [];
    var parts = String(str === null || str === undefined ? "" : str).split(",");
    for (var i = 0; i < parts.length; i++) {
        var id = parts[i].trim();
        if (id.length === 0 || allowed.indexOf(id) === -1 || out.indexOf(id) !== -1) {
            continue;
        }
        out.push(id);
    }
    return out;
}

function serializeWidgetList(ids) {
    return (ids || []).join(",");
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

// Moves one element, returning a new array. `to` clamps into range; an
// out-of-range `from` is a no-op.
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
