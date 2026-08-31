.pragma library

// Registry of panel widgets and quick toggle pills for 2D grid layout (1x1, 2x1, 2x2, 3x1, 3x2).
var CATALOG = [
    { id: "network", label: "Wi-Fi / Network", icon: "network-wireless", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "bluetooth", label: "Bluetooth", icon: "preferences-system-bluetooth", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "dnd", label: "Do Not Disturb", icon: "notifications-disabled", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "nightlight", label: "Night Light", icon: "weather-clear-night", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "darkmode", label: "Dark Theme", icon: "color-management", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "power", label: "Power & Session", icon: "system-shutdown", file: "widgets/QuickToggleWidget.qml", requiresModule: "", defaultSpanW: 1, defaultSpanH: 1 },
    { id: "volume", label: "Volume", icon: "audio-volume-high", file: "widgets/VolumeWidget.qml", requiresModule: "", defaultSpanW: 3, defaultSpanH: 1 },
    { id: "brightness", label: "Brightness", icon: "display-brightness", file: "widgets/BrightnessWidget.qml", requiresModule: "", defaultSpanW: 3, defaultSpanH: 1 },
    { id: "media", label: "Media controls", icon: "media-playback-start", file: "widgets/MediaWidget.qml", requiresModule: "enableMedia", defaultSpanW: 3, defaultSpanH: 2 },
    { id: "system", label: "System resources", icon: "utilities-system-monitor", file: "widgets/SystemWidget.qml", requiresModule: "enableSysMonitor", defaultSpanW: 3, defaultSpanH: 2 },
    { id: "timer", label: "Timer", icon: "chronometer", file: "widgets/TimerWidget.qml", requiresModule: "enableTimer", defaultSpanW: 3, defaultSpanH: 1 },
    { id: "notifications", label: "Notifications", icon: "notifications", file: "widgets/NotificationsWidget.qml", requiresModule: "enableNotifications", defaultSpanW: 3, defaultSpanH: 2 },
    { id: "clock", label: "Clock", icon: "preferences-system-time", file: "widgets/ClockWidget.qml", requiresModule: "", defaultSpanW: 3, defaultSpanH: 1 }
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
function defaultSpanWFor(id) { var e = entryFor(id); return e ? (e.defaultSpanW || 3) : 3; }
function defaultSpanHFor(id) { var e = entryFor(id); return e ? (e.defaultSpanH || 1) : 1; }

function isAvailable(id, config) {
    var req = requiresModule(id);
    if (req === "") return true;
    if (!config) return true;
    if (config[req] === undefined) return true;
    return config[req] === true;
}
