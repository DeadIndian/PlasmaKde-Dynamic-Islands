// Runs the QML JS library under plain node. `.pragma library` is a valid QML
// directive but invalid JavaScript, so it is stripped before evaluating.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(
    join(here, "..", "package", "contents", "ui", "IslandUtils.js"),
    "utf8",
);
const stripped = source.replace(/^\s*\.(pragma|import)[^\n]*$/gm, "");
const U = {};
new Function(
    "exports",
    stripped +
        "\nexports.formatTemplate = formatTemplate;" +
        "\nexports.parseWidgetList = parseWidgetList;" +
        "\nexports.serializeWidgetList = serializeWidgetList;" +
        "\nexports.parseWidgetSpecs = parseWidgetSpecs;" +
        "\nexports.serializeWidgetSpecs = serializeWidgetSpecs;" +
        "\nexports.cycleSpan2D = cycleSpan2D;" +
        "\nexports.mmss = mmss;" +
        "\nexports.moveItem = moveItem;",
)(U);

const tokens = { title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", player: "VLC" };

// formatTemplate
assert.equal(U.formatTemplate("{title}", tokens), "Bohemian Rhapsody");
assert.equal(U.formatTemplate("{artist} — {album}", tokens), "Queen — A Night at the Opera");
assert.equal(U.formatTemplate("{title} ({player})", tokens), "Bohemian Rhapsody (VLC)");
assert.equal(U.formatTemplate("no tokens here", tokens), "no tokens here");
assert.equal(U.formatTemplate("", tokens), "");
assert.equal(U.formatTemplate("{titel}", tokens), "{titel}");
assert.equal(U.formatTemplate("{artist}", { artist: "" }), "");
assert.equal(U.formatTemplate("{artist}", { artist: null }), "");
assert.equal(U.formatTemplate("{artist}", { artist: undefined }), "");

// parseWidgetList
const valid = ["media", "system", "timer", "volume", "brightness", "clock", "network", "bluetooth", "dnd", "nightlight", "darkmode", "power"];
assert.deepEqual(U.parseWidgetList("media,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("system,media", valid), ["system", "media"]);
assert.deepEqual(U.parseWidgetList(" media , system ", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("media,nope,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("media,media,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("", valid), []);

// parseWidgetSpecs & serializeWidgetSpecs 2D
const specStr = "network:1:1,volume:3:1,media:2:2";
const parsedSpecs = U.parseWidgetSpecs(specStr, valid);
assert.deepEqual(parsedSpecs, [
    { id: "network", spanW: 1, spanH: 1 },
    { id: "volume", spanW: 3, spanH: 1 },
    { id: "media", spanW: 2, spanH: 2 }
]);
assert.equal(U.serializeWidgetSpecs(parsedSpecs), "network:1:1,volume:3:1,media:2:2");

// cycleSpan2D
assert.deepEqual(U.cycleSpan2D(1, 1), { spanW: 2, spanH: 1 });
assert.deepEqual(U.cycleSpan2D(2, 1), { spanW: 2, spanH: 2 });
assert.deepEqual(U.cycleSpan2D(2, 2), { spanW: 3, spanH: 1 });
assert.deepEqual(U.cycleSpan2D(3, 1), { spanW: 3, spanH: 2 });
assert.deepEqual(U.cycleSpan2D(3, 2), { spanW: 1, spanH: 1 });

// cycleSpan2D with maxCols = 2 (small panel setting)
assert.deepEqual(U.cycleSpan2D(1, 1, 2), { spanW: 2, spanH: 1 });
assert.deepEqual(U.cycleSpan2D(2, 1, 2), { spanW: 2, spanH: 2 });
assert.deepEqual(U.cycleSpan2D(2, 2, 2), { spanW: 1, spanH: 1 });

// cycleSpan2D with maxCols = 4 (large panel setting - 4x2 and 4x3 support)
assert.deepEqual(U.cycleSpan2D(3, 2, 4), { spanW: 4, spanH: 1 });
assert.deepEqual(U.cycleSpan2D(4, 1, 4), { spanW: 4, spanH: 2 });
assert.deepEqual(U.cycleSpan2D(4, 2, 4), { spanW: 4, spanH: 3 });
assert.deepEqual(U.cycleSpan2D(4, 3, 4), { spanW: 1, spanH: 1 });

// mmss
assert.equal(U.mmss(0), "00:00");
assert.equal(U.mmss(9), "00:09");
assert.equal(U.mmss(3600), "1:00:00");

// moveItem
const base = ["a", "b", "c", "d"];
assert.deepEqual(U.moveItem(base, 0, 2), ["b", "c", "a", "d"]);

console.log("islandutils: all assertions passed");
