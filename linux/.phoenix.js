/**
 * Phoenix
 * doc: https://github.com/kasper/phoenix/wiki
 * Global settings
 */

/**
 * Preferences
 */
Phoenix.set({
  'daemon': false,
  'openAtLogin': true
});

var mash = ["alt"];
var mashShift = ["alt", "shift"];
var mashCtrl = ["alt", "ctrl"];
var mashCmd = ["alt", "cmd"];

var mousePositions = {}; // mouse position for window
var activeWindowsTimes = {}; // last active time for window

/**
 * Utils functions
 */

function alert(message) {
  var modal = new Modal();
  modal.message = message;
  modal.duration = 2;
  modal.show();
}

function assert(condition, message) {
  if (!condition) {
    throw message || "Assertion failed";
  }
}

if (!String.format) {
  String.format = function (format) {
    var args = Array.prototype.slice.call(arguments, 1);
    return format.replace(/{(\d+)}/g, function (match, number) {
      return typeof args[number] != 'undefined' ? args[number] : match;
    });
  };
}

function alertTitle(window) {
  alert(window.title());
}

/**
 * Mouse functions
 */

function saveMousePositionForWindow(window) {
  if (!window) { return; }
  heartbeatWindow(window);
  var pos = Mouse.location();
  mousePositions[window.hash()] = pos;
  Phoenix.log(String.format("save mouse pos for {0}, x:{1}, y:{2}", window.app().name(), pos.x, pos.y));
}

function setMousePositionCenterForWindow(window) {
  var pos = {
    x: window.topLeft().x + window.frame().width / 2,
    y: window.topLeft().y + window.frame().height / 2
  }

  Phoenix.log(String.format('move mouse to pos for {0} x: {1}, y: {2}', window.app().name(), pos.x, pos.y));
  Mouse.move(pos);
  heartbeatWindow(window);
}

function restoreMousePositionForWindow(window) {
  if (!mousePositions[window.hash()]) {
    setMousePositionCenterForWindow(window);
    return;
  }
  var pos = mousePositions[window.hash()];
  var rect = window.frame();
  if (pos.x < rect.x || pos.x > (rect.x + rect.width) || pos.y < rect.y || pos.y > (rect.y + rect.height)) {
    setMousePositionCenterForWindow(window);
    return;
  }
  Phoenix.log(String.format('move mouse to pos for {0} x: {1}, y: {2}', window.app().name(), pos.x, pos.y));
  Mouse.move(pos);
  heartbeatWindow(window);
}

/**
 * Window functions
 */

function heartbeatWindow(window) {
  activeWindowsTimes[window.app().pid] = new Date().getTime() / 1000;
}

/**
 * App functions
 */

// switch app, and remember mouse position

function callApp(appName) {
  var window = Window.focused();
  if (window) {
    saveMousePositionForWindow(window)
  }
  var app = App.launch(appName);
  Timer.after(0.300, function () {
    app.focus();
    var newWindow = _.first(app.windows());
    if (newWindow && window !== newWindow) {
      restoreMousePositionForWindow(newWindow);
    }
  });
}

/**
 * App configuration
 */

// Launch app
Key.on('`', mash, function () { callApp('iTerm'); });
Key.on('1', mash, function () { callApp('Google Chrome'); });
Key.on('2', mash, function () { callApp('Safari'); });
Key.on('e', mash, function () { callApp('VSCode'); });