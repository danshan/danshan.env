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
  modal.text = message;
  modal.origin = (0, 0);
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

function sortByMostRecent(windows) {
  var visibleAppMostRecentFirst = _.map(
    Window.recent(), function (w) { return w.hash(); }
  );
  var visibleAppMostRecentFirstWithWeight = _.zipObject(
    visibleAppMostRecentFirst, _.range(visibleAppMostRecentFirst.length)
  );
  return _.sortBy(windows, function (window) { return visibleAppMostRecentFirstWithWeight[window.hash()]; });
};

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

function centralMouse() {
  var window = getCurrentWindow();
  if (!window) return;
  setMousePositionCenterForWindow(window);
}

/**
 * Window functions
 */

function heartbeatWindow(window) {
  activeWindowsTimes[window.app().pid] = new Date().getTime() / 1000;
}

function maximizeCurrentWindow() {
  var window = getCurrentWindow();
  if (!window) return;

  window.maximize();
  heartbeatWindow(window);
}

function getResizeFrame(frame, ratio) {
  var mid_pos_x = frame.x + 0.5 * frame.width;
  var mid_pos_y = frame.y + 0.5 * frame.height;
  return {
    x: Math.round(frame.x + frame.width / 2 * (1 - ratio)),
    y: Math.round(frame.y + frame.height / 2 * (1 - ratio)),
    width: Math.round(frame.width * ratio),
    height: Math.round(frame.height * ratio)
  }
}

function getSmallerFrame(frame) {
  return getResizeFrame(frame, 0.9);
}

function getLargerFrame(frame) {
  return getResizeFrame(frame, 1.1);
}

function adapterScreenFrame(windowFrame, screenFrame) {
  return {
    x: Math.max(screenFrame.x, windowFrame.x),
    y: Math.max(screenFrame.y, windowFrame.y),
    width: Math.min(screenFrame.width, windowFrame.width),
    height: Math.min(screenFrame.height, windowFrame.height)
  };
}

function fitScreenHeight() {
  var window = getCurrentWindow();
  if (!window) return;

  window.setFrame({
    x: window.frame().x,
    y: window.screen().flippedVisibleFrame().y,
    width: window.frame().width,
    height: window.screen().flippedVisibleFrame().height
  });
  heartbeatWindow(window);
}

function fitScreenWidth() {
  var window = getCurrentWindow();
  if (!window) return;

  window.setFrame({
    x: window.screen().flippedVisibleFrame().x,
    y: window.frame().y,
    width: window.screen().flippedVisibleFrame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}

function smallerCurrentWindow() {
  var window = getCurrentWindow();
  var screenFrame = window.screen().flippedVisibleFrame();
  if (!window) return;

  var originFrame = window.frame();
  var frame = getSmallerFrame(originFrame);
  window.setFrame(adapterScreenFrame(frame, screenFrame));
}

function largerCurrentWindow() {
  var window = getCurrentWindow();
  var screenFrame = window.screen().flippedVisibleFrame();
  if (!window) return;

  var originFrame = window.frame();
  var frame = getLargerFrame(originFrame);
  window.setFrame(adapterScreenFrame(frame, screenFrame));
}

function centralCurrentWindow() {
  var window = getCurrentWindow();
  if (!window) return;

  setWindowCentral(window);
}

function setWindowCentral(window) {
  window.setTopLeft({
    x: (window.screen().flippedVisibleFrame().width - window.size().width) / 2 + window.screen().flippedVisibleFrame().x,
    y: (window.screen().flippedVisibleFrame().height - window.size().height) / 2 + window.screen().flippedVisibleFrame().y
  });
  heartbeatWindow(window);
};

function moveCurrentWindow(x, y) {
  var window = getCurrentWindow();
  if (!window) return;

  window.setFrame({
    x: window.frame().x + x,
    y: window.frame().y + y,
    width: window.frame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}

function getAnotherWindowOfCurrentScreen(window, offset) {
  var windows = window.others({ visible: true, screen: window.screen() });
  windows.push(window);
  var screen = window.screen();
  windows = _.chain(windows).sortBy(function (window) {
    return window.app().pid + "-" + window.hash();
  }).value();

  var index = (_.indexOf(windows, window) + offset + windows.length) % windows.length;
  return windows[index];
}

function getPreviousWindowOfCurrentScreen() {
  var window = getCurrentWindow();
  if (!window) {
    if (Window.recent().length == 0) return;
    Window.recent()[0].focus();
    return;
  }
  saveMousePositionForWindow(window);
  var targetWindow = getAnotherWindowOfCurrentScreen(window, -1)
  if (!targetWindow) {
    return;
  }
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}

function getNextWindowsOfCurrentScreen() {
  var window = getCurrentWindow();
  if (!window) {
    if (Window.recent().length == 0) return;
    Window.recent()[0].focus();
    return;
  }
  saveMousePositionForWindow(window);
  var targetWindow = getAnotherWindowOfCurrentScreen(window, 1)
  if (!targetWindow) {
    return;
  }
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}

/**
 * App functions
 */

// switch app, and remember mouse position

function callApp(appName) {
  var window = getCurrentWindow();
  if (window) {
    saveMousePositionForWindow(window)
  }
  var app = App.get(appName);
  if (!app) app = App.launch(appName);

  Timer.after(0.100, function () {
    app.focus();
    var newWindow = _.first(app.windows());
    if (newWindow && window.hash() != newWindow.hash()) {
      restoreMousePositionForWindow(newWindow);
    }
  });
}

/**
 * Screen functions
 */

function moveToScreen(window, screen) {
  if (!window) return;
  if (!screen) return;

  var frame = window.frame();
  var oldScreenRect = window.screen().visibleFrameInRectangle();
  var newScreenRect = screen.visibleFrameInRectangle();
  var xRatio = newScreenRect.width / oldScreenRect.width;
  var yRatio = newScreenRect.height / oldScreenRect.height;

  var mid_pos_x = frame.x + Math.round(0.5 * frame.width);
  var mid_pos_y = frame.y + Math.round(0.5 * frame.height);

  window.setFrame({
    x: (mid_pos_x - oldScreenRect.x) * xRatio + newScreenRect.x - 0.5 * frame.width,
    y: (mid_pos_y - oldScreenRect.y) * yRatio + newScreenRect.y - 0.5 * frame.height,
    width: frame.width,
    height: frame.height
  });
};

function getCurrentWindow() {
  var window = Window.focused();
  if (!window) {
    window = App.focused().mainWindow();
  }
  if (!window) return;
  return window;
}

function focusAnotherScreen(window, targetScreen) {
  if (!window) return;
  var currentScreen = window.screen();
  if (window.screen() === targetScreen) return;

  saveMousePositionForWindow(window);
  var targetScreenWindows = sortByMostRecent(targetScreen.windows());
  if (targetScreenWindows.length == 0) {
    return;
  }
  var targetWindow = targetScreenWindows[0]
  targetWindow.focus();  // bug, two window in two space, focus will focus in same space first
  restoreMousePositionForWindow(targetWindow);
}

function focusOnNextScreen() {
  var window = getCurrentWindow();
  if (!window) return;

  var allScreens = Screen.all();
  var currentScreen = window.screen();
  if (!currentScreen) return;
  var targetScreen = currentScreen.next();
  if (_.indexOf(_.map(allScreens, function (x) { return x.hash(); }), targetScreen.hash())
    >= _.indexOf(_.map(allScreens, function (x) { return x.hash(); }), currentScreen.hash())) {
    return;
  } else {
    focusAnotherScreen(window, targetScreen);
  }
}

function focusOnPreviousScreen() {
  var window = getCurrentWindow();
  if (!window) return;

  var allScreens = Screen.all();
  var currentScreen = window.screen();
  if (!currentScreen) return;
  var targetScreen = currentScreen.previous();
  if (_.indexOf(_.map(allScreens, function (x) { return x.hash(); }), targetScreen.hash())
    <= _.indexOf(_.map(allScreens, function (x) { return x.hash(); }), currentScreen.hash())) {
    return;
  } else {
    focusAnotherScreen(window, targetScreen);
  }
}

function moveToNextScreen() {
  var window = getCurrentWindow();
  if (!window) return;

  if (window.screen() === window.screen().next()) return;
  moveToScreen(window, window.screen().next());
  restoreMousePositionForWindow(window);
  window.focus();
}

function moveToPreviousScreen() {
  var window = getCurrentWindow();
  if (!window) return;

  if (window.screen() === window.screen().next()) return;
  moveToScreen(window, window.screen().previous());
  restoreMousePositionForWindow(window);
  window.focus();
}

/**
 * App configuration
 */

// Launch app
Key.on('`', mash, function () { callApp('iTerm'); });
Key.on('1', mash, function () { callApp('Google Chrome'); });
Key.on('2', mash, function () { callApp('Safari'); });
Key.on('4', mash, function () { callApp('WeChat'); });
Key.on('w', mash, function () { callApp('KeePassXC'); });
Key.on('e', mash, function () { callApp('VSCode'); });
Key.on('s', mash, function () { callApp('IntelliJ IDEA Ultimate'); });
Key.on(',', mash, function () { callApp('Quiver'); });
Key.on('.', mash, function () { callApp('Microsoft Outlook'); });
Key.on('/', mash, function () { callApp('Finder'); });
Key.on(';', mash, function () { callApp('Preview'); });
Key.on('n', mash, function () { callApp('Slack'); });
Key.on('m', mash, function () { callApp('Mail'); });

/**
 * Screen configuration
 */

// Next screen
Key.on('l', mash, function () { focusOnNextScreen(); });
// Previous screen
Key.on('h', mash, function () { focusOnPreviousScreen(); });
// Move current window to next screen
Key.on('l', mashShift, function () { moveToNextScreen(); });
// Move current window to previous screen
Key.on('h', mashShift, function () { moveToPreviousScreen(); });

/**
 * Window configuration
 */

// Window maximize
Key.on('m', mashShift, function () { maximizeCurrentWindow(); });
// Window smaller 
Key.on('-', mash, function () { smallerCurrentWindow(); });
// Window larger 
Key.on('=', mash, function () { largerCurrentWindow(); });
// Window central 
Key.on('m', mash, function () { centralCurrentWindow(); });
// Window fit screen height
Key.on('\\', mash, function () { fitScreenHeight(); });
// Window fit screen width 
Key.on('\\', mashShift, function () { fitScreenWidth(); });
// Window <
Key.on('h', mashCtrl, function () { moveCurrentWindow(-100, 0); });
// Window >
Key.on('l', mashCtrl, function () { moveCurrentWindow(100, 0); });
// Window ^
Key.on('k', mashCtrl, function () { moveCurrentWindow(0, -100); });
// Window v
Key.on('j', mashCtrl, function () { moveCurrentWindow(0, 100); });

// Previous Window in One Screen
Key.on('j', mash, function () { getNextWindowsOfCurrentScreen(); });
Key.on('k', mash, function () { getPreviousWindowOfCurrentScreen(); });

/**
 * Mouse configuration
 */

Key.on('space', mash, function () { centralMouse(); })
