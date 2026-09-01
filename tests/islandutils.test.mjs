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
        "\nexports.parseCell = parseCell;" +
        "\nexports.buildOccupancy = buildOccupancy;" +
        "\nexports.fits = fits;" +
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

// parseWidgetSpecs & serializeWidgetSpecs — 5-field explicit placement
const placedStr = "network:0:0:1:1,volume:0:1:3:1,media:0:2:2:2";
const placed = U.parseWidgetSpecs(placedStr, valid);
assert.deepEqual(placed, [
    { id: "network", col: 0, row: 0, spanW: 1, spanH: 1 },
    { id: "volume", col: 0, row: 1, spanW: 3, spanH: 1 },
    { id: "media", col: 0, row: 2, spanW: 2, spanH: 2 }
]);
assert.equal(U.serializeWidgetSpecs(placed), placedStr);

// Legacy 3-field entries parse as unplaced.
const legacy = U.parseWidgetSpecs("network:1:1,volume:3:1,media:2:2", valid);
assert.deepEqual(legacy, [
    { id: "network", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "volume", col: -1, row: -1, spanW: 3, spanH: 1 },
    { id: "media", col: -1, row: -1, spanW: 2, spanH: 2 }
]);
assert.equal(
    U.serializeWidgetSpecs(legacy),
    "network:-1:-1:1:1,volume:-1:-1:3:1,media:-1:-1:2:2",
);

// "-1" survives a round-trip as unplaced rather than becoming a literal cell.
assert.deepEqual(U.parseWidgetSpecs("network:-1:-1:1:1", valid), [
    { id: "network", col: -1, row: -1, spanW: 1, spanH: 1 }
]);

// Out-of-range col/row degrade to unplaced, field by field.
assert.deepEqual(U.parseWidgetSpecs("network:9:0:1:1,volume:0:999:3:1", valid), [
    { id: "network", col: -1, row: 0, spanW: 1, spanH: 1 },
    { id: "volume", col: 0, row: -1, spanW: 3, spanH: 1 }
]);

// Legacy short forms still fall back to catalog defaults.
const wDefaults = { media: 3, network: 1 };
const hDefaults = { media: 2, network: 1 };
assert.deepEqual(U.parseWidgetSpecs("media", valid, wDefaults, hDefaults), [
    { id: "media", col: -1, row: -1, spanW: 3, spanH: 2 }
]);
assert.deepEqual(U.parseWidgetSpecs("media:2", valid, wDefaults, hDefaults), [
    { id: "media", col: -1, row: -1, spanW: 2, spanH: 2 }
]);

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

// buildOccupancy & fits
const grid4 = [
    { id: "network", col: 0, row: 0, spanW: 1, spanH: 1 },
    { id: "bluetooth", col: 1, row: 0, spanW: 1, spanH: 1 },
    { id: "media", col: 0, row: 1, spanW: 3, spanH: 2 }
];
const occ4 = U.buildOccupancy(grid4, 4);
assert.equal(occ4[0][0], 0);
assert.equal(occ4[0][1], 1);
assert.equal(occ4[0][2], undefined);
assert.equal(occ4[2][2], 2, "media spans down into row 2");
assert.equal(occ4[1][3], undefined, "media is 3 wide, column 3 is free");

// skipIndex lifts one widget out, which is what a drag needs.
const occNoMedia = U.buildOccupancy(grid4, 4, 2);
assert.equal(occNoMedia[1], undefined);
assert.equal(occNoMedia[0][0], 0);

// Unplaced widgets occupy nothing.
assert.deepEqual(U.buildOccupancy([{ id: "x", col: -1, row: -1, spanW: 1, spanH: 1 }], 4), []);

assert.equal(U.fits(occ4, 2, 0, 1, 1, 4), true, "free cell");
assert.equal(U.fits(occ4, 0, 0, 1, 1, 4), false, "occupied cell");
assert.equal(U.fits(occ4, 3, 1, 1, 1, 4), true, "beside media");
assert.equal(U.fits(occ4, 2, 0, 3, 1, 4), false, "overflows the right edge");
assert.equal(U.fits(occ4, 3, 0, 1, 1, 4), true, "last column is in bounds");
assert.equal(U.fits(occ4, -1, 0, 1, 1, 4), false, "negative col");
assert.equal(U.fits(occ4, 0, -1, 1, 1, 4), false, "negative row");
assert.equal(U.fits(occ4, 0, 5, 3, 2, 4), true, "empty rows below the content");

console.log("islandutils: all assertions passed");
