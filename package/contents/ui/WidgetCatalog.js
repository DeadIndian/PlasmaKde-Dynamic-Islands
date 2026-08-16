.pragma library

// Registry of panel widgets. `requiresModule` names a Plasmoid.configuration
// key (e.g. "enableMedia") that must be true for the widget to appear; an
// empty string means the widget is always available. Adding a module later
// costs one widget file, one catalog line, one config page and one config
// entry group.
var CATALOG = [
    { id: "media", label: "Media controls", icon: "media-playback-start", file: "widgets/MediaWidget.qml", requiresModule: "enableMedia" },
    { id: "system", label: "System resources", icon: "utilities-system-monitor", file: "widgets/SystemWidget.qml", requiresModule: "enableSysMonitor" },
    { id: "timer", label: "Timer", icon: "chronometer", file: "widgets/TimerWidget.qml", requiresModule: "enableTimer" },
    { id: "volume", label: "Volume", icon: "audio-volume-high", file: "widgets/VolumeWidget.qml", requiresModule: "" },
    { id: "brightness", label: "Brightness", icon: "brightness-low", file: "widgets/BrightnessWidget.qml", requiresModule: "" },
    { id: "clock", label: "Clock", icon: "preferences-system-time", file: "widgets/ClockWidget.qml", requiresModule: "" }
];

function entryFor(id) {
    for (var i = 0; i < CATALOG.length; i++) {
        if (CATALOG[i].id === id) {
            return CATALOG[i];
        }
    }
    return null;
}

function ids() {
    var out = [];
    for (var i = 0; i < CATALOG.length; i++) {
        out.push(CATALOG[i].id);
    }
    return out;
}

function fileFor(id) { var e = entryFor(id); return e ? e.file : ""; }
function labelFor(id) { var e = entryFor(id); return e ? e.label : ""; }
function iconFor(id) { var e = entryFor(id); return e ? e.icon : ""; }
function requiresModule(id) { var e = entryFor(id); return e ? e.requiresModule : ""; }

function isAvailable(id, config) {
    var req = requiresModule(id);
    return req === "" || config[req] === true;
}
