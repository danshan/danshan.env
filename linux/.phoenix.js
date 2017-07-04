/**
 * Phoenix
 * doc: https://github.com/kasper/phoenix/wiki
 * Global settings
 */

var keys = [];
var alt = ['alt'];
var cmd = ['cmd'];
var cmdAlt = ['cmd', 'alt'];
var altShift = ['alt', 'shift'];
var altCtrl = ['alt', 'ctrl'];


var mousePositions = {};
var ACTIVE_WINDOWS_TIMES = {};
var HIDE_INACTIVE_WINDOW_TIME = 10; // minitus
var DEFAULT_WIDTH = 1280;
var A_BIG_PIXEL = 10000;

var WORK_SPACE_INDEX_MAP = {}; // is a dict, key is display count, val is work space
WORK_SPACE_INDEX_MAP[1] = 0; // one display case
WORK_SPACE_INDEX_MAP[2] = 3; // two display case
var PARK_SPACE_INDEX_MAP = {};
PARK_SPACE_INDEX_MAP[1] = 2;
PARK_SPACE_INDEX_MAP[2] = 2;
var PARK_SPACE_APP_INDEX_MAP = {};
PARK_SPACE_APP_INDEX_MAP['iTerm'] = 0;
PARK_SPACE_APP_INDEX_MAP['Safari'] = 1;
PARK_SPACE_APP_INDEX_MAP['QQ'] = 1;
PARK_SPACE_APP_INDEX_MAP['WeChat'] = 1;
PARK_SPACE_APP_INDEX_MAP['BearyChat'] = 1;
PARK_SPACE_APP_INDEX_MAP['Mail'] = 1;



if (!String.format) {
  String.format = function(format) {
    var args = Array.prototype.slice.call(arguments, 1);
    return format.replace(/{(\d+)}/g, function(match, number) {
      return typeof args[number] != 'undefined' ? args[number] : match;
    });
  };
}

var alert_title = function(window) {
  alert(window.title());
};

/**
 * Utils Functions
 */

function alert(message) {
  var modal = new Modal();
  modal.message = message;
  modal.duration = 1;
  modal.show();
}

function assert(condition, message) {
  if (!condition) {
    throw message || "Assertion failed";
  }
}


function sortByMostRecent(windows) {
  var visibleAppMostRecentFirst = _.map(
    Window.recent(),
    function(w) {
      return w.hash();
    }
  );
  var visibleAppMostRecentFirstWithWeight = _.object(
    visibleAppMostRecentFirst, _.range(visibleAppMostRecentFirst.length)
  );
  return _.sortBy(windows, function(window) {
    return visibleAppMostRecentFirstWithWeight[window.hash()];
  });
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

function getCurrentWindow() {
  var window = Window.focused();
  if (window === undefined) {
  window = App.focused().mainWindow();
  }
  if (window === undefined) {
  return;
  }
  return window;
}

/**
 * Screen Functions
 */

function moveToScreen(window, screen) {
  if (!window) return;
  if (!screen) return;

  var frame = window.frame();
  var oldScreenRect = window.screen().frameInRectangle();
  var newScreenRect = screen.frameInRectangle();
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

function windowsOnOtherScreen() {
  var otherWindowsOnSameScreen = Window.focused().others({ screen: Window.focused().screen() });  // slow
  var otherWindowTitlesOnSameScreen = _.map(otherWindowsOnSameScreen , function(w) { return w.title(); });
  var return_value = _.chain(Window.focused().others())
    .filter(function(window) { return ! _.contains(otherWindowTitlesOnSameScreen, window.title()); })
    .value();
  return return_value;
};

/**
 * Window Functions
 */

function hideInactiveWindow(windows) {
  var now = new Date().getTime() / 1000;
  _.chain(windows).filter(function(window) {
    if (!ACTIVE_WINDOWS_TIMES[window.app().pid]) {
      ACTIVE_WINDOWS_TIMES[window.app().pid] = now;
      return false;
    } return true;
  }).filter(function(window) {
    return now - ACTIVE_WINDOWS_TIMES[window.app().pid]> HIDE_INACTIVE_WINDOW_TIME * 60;
    //return now - ACTIVE_WINDOWS_TIMES[window.app().pid]> 5;
  }).map(function(window) {window.app().hide()});
}

function heartbeatWindow(window) {
  ACTIVE_WINDOWS_TIMES[window.app().pid] = new Date().getTime() / 1000;
  //hide_inactiveWindow(window.otherWindowsOnSameScreen());
}

function getAnotherWindowsOnSameScreen(window, offset, isCycle) {
  var windows = window.others({ visible: true, screen: window.screen() });
  windows.push(window);
  var screen = window.screen();
  windows = _.chain(windows).sortBy(function(window) {
    return [(A_BIG_PIXEL + window.frame().y - screen.frameInRectangle().y) +
    (A_BIG_PIXEL + window.frame().x - screen.frameInRectangle().y),
    window.app().pid, window.title()].join('');
  }).value();
  if (isCycle) {
  var index = (_.indexOf(windows, window) + offset + windows.length) % windows.length;
  } else {
  var index = _.indexOf(windows, window) + offset;
  }
  //alert(windows.length);
  //alert(_.map(windows, function(x) {return x.title();}).join(','));
  //alert(_.map(windows, function(x) {return x.app().name();}).join(','));
  if (index >= windows.length || index < 0) {
  return;
  }
  return windows[index];
}

function getPreviousWindowsOnSameScreen(window) {
  return getAnotherWindowsOnSameScreen(window, -1, false)
};

function getNextWindowsOnSameScreen(window) {
  return getAnotherWindowsOnSameScreen(window, 1, false)
};

function setWindowCentral(window) {
  window.setTopLeft({
    x: (window.screen().frameInRectangle().width - window.size().width) / 2 + window.screen().frameInRectangle().x,
    y: (window.screen().frameInRectangle().height - window.size().height) / 2 + window.screen().frameInRectangle().y
  });
  heartbeatWindow(window);
};

/**
 * Mouse Functions
 */

function saveMousePositionForWindow(window) {
  if (!window) return;
  heartbeatWindow(window);
  mousePositions[window.title()] = Mouse.location();
}


function setMousePositionForWindowCenter(window) {
  Mouse.move({
    x: window.topLeft().x + window.frame().width / 2,
    y: window.topLeft().y + window.frame().height / 2
  });
  heartbeatWindow(window);
}

function restoreMousePositionForWindow(window) {
  if (!mousePositions[window.title()]) {
    setMousePositionForWindowCenter(window);
    return;
  }
  var pos = mousePositions[window.title()];
  var rect = window.frame();
  if (pos.x < rect.x || pos.x > (rect.x + rect.width) || pos.y < rect.y || pos.y > (rect.y + rect.height)) {
    setMousePositionForWindowCenter(window);
    return;
  }
  Mouse.move(pos);
  heartbeatWindow(window);
}

function restoreMousePositionForNow() {
  if (Window.focused() === undefined) {
    return;
  }
  restoreMousePositionForWindow(Window.focused());
}

/**
 * App Functions
 */

function launchOrFocus(appName) {
  var app = App.launch(appName);
  assert(app !== undefined);
  app.focus();
  return app;
}

//switch app, and remember mouse position
function callApp(appName) {
  var window = Window.focused();
  if (window) {
    saveMousePositionForWindow(window);
  }
  var newWindow = _.first(launchOrFocus(appName).windows());
  if (newWindow && window !== newWindow) {
    restoreMousePositionForWindow(newWindow);
  }
}

/**
 * My Configuartion Global
 */

Phoenix.set({
    'daemon': false,
    'openAtLogin': true
});

/**
 * My Configuartion App
 */

keys.push(new Key('`', alt, function() { callApp('iTerm'); }));
keys.push(new Key('1', alt, function() { callApp('Google Chrome'); }));
keys.push(new Key('2', alt, function() { callApp('Opera'); }));
keys.push(new Key('3', alt, function() { callApp('wanda'); }));
keys.push(new Key('4', alt, function() { callApp('Wechat'); }));
keys.push(new Key('w', alt, function() { callApp('KeePassXC'); }));
keys.push(new Key('s', alt, function() { callApp('IntelliJ IDEA CE'); }));
keys.push(new Key('e', alt, function() { callApp('Sublime Text'); }));
keys.push(new Key(',', alt, function() { callApp('Quiver'); }));
keys.push(new Key('.', alt, function() { callApp('Microsoft Outlook'); }));
keys.push(new Key('/', alt, function() { callApp('Finder'); }));
keys.push(new Key(';', alt, function() { callApp('Preview'); }));
keys.push(new Key('n', alt, function() { callApp('Slack'); }));

/**
 * My Configuartion Screen
 */

function focusAnotherScreen(window, targetScreen) {
  if (!window) return;
  var currentScreen = window.screen();
  if (window.screen() === targetScreen) return;
  //if (targetScreen.frameInRectangle().x < currentScreen.frameInRectangle().x) {
    //return;
  //}
  saveMousePositionForWindow(window);
  var targetScreenWindows = sortByMostRecent(targetScreen.windows());
  if (targetScreenWindows.length == 0) {
    return;
  }
  var targetWindow = targetScreenWindows[0]
  targetWindow.focus();  // bug, two window in two space, focus will focus in same space first
  restoreMousePositionForWindow(targetWindow);
}

// Next screen, now only support 2 display 
keys.push(new Key('l', alt, function() {
  saveMousePositionForWindow(window);
  var window = getCurrentWindow();
  if (!window) return;
  if (window.screen() === window.screen().next()) return;
  if (window.screen().next().frameInRectangle().x < window.screen().frameInRectangle().x) {
    return;
  }

  saveMousePositionForWindow(window);
  var nextScreenWindows = sortByMostRecent(windowsOnOtherScreen());
  if (nextScreenWindows.length > 0) {
    nextScreenWindows[0].focus();
    restoreMousePositionForWindow(nextScreenWindows[0]);
  }
}));

// Previous Screen, now only support 2 display // TODO
keys.push(new Key('h', alt, function() {
  var window = getCurrentWindow();
  if (!window) return;
  if (window.screen() === window.screen().next()) return;
  if (window.screen().next().frameInRectangle().x > window.screen().frameInRectangle().x) {
    return;
  }
  saveMousePositionForWindow(window);
  var nextScreenWindows = sortByMostRecent(windowsOnOtherScreen()); // find it!!! cost !!!
  if (nextScreenWindows.length > 0) {
    nextScreenWindows[0].focus();
    restoreMousePositionForWindow(nextScreenWindows[0]);
  }
}));

// Move Current Window to Next Screen
keys.push(new Key('l', altShift, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  if (window.screen() === window.screen().next()) return;
  if (window.screen().next().frameInRectangle().x < 0) {
    return;
  }
  moveToScreen(window, window.screen().next());
  restoreMousePositionForWindow(window);
  window.focus();
}));

// Move Current Window to Previous Screen
keys.push(new Key('h', altShift, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  if (window.screen() === window.screen().next()) return;
  if (window.screen().next().frameInRectangle().x == 0) {
    return;
  }
  moveToScreen(window, window.screen().previous());
  restoreMousePositionForWindow(window);
  window.focus();
}));


// Window Smaller

keys.push(new Key('-', alt, function() {
  var window = getCurrentWindow();
  if (!window) return;
  var oldFrame = window.frame();
  var frame = getSmallerFrame(oldFrame);
  window.setFrame(frame);
  if (window.frame().width == oldFrame.width || window.frame().height == oldFrame.height) {
    window.setFrame(oldFrame);
  }
}));

// Window Larger
keys.push(new Key('=', alt, function() {
  var window = getCurrentWindow();
  if (!window) return;
  var frame = getLargerFrame(window.frame());
  if (frame.width > window.screen().frameInRectangle().width ||
    frame.height > window.screen().frameInRectangle().height) {
    window.maximize();
  } else {
    window.setFrame(frame);
  }
}));

// Window Maximize
keys.push(new Key('m', altShift, function() {
  var window = getCurrentWindow();
  if (!window) return;
  window.maximize();
  setWindowCentral(window);
}));

// Window Central
keys.push(new Key('m', alt, function() {
  var window = getCurrentWindow();
  if (!window) return;
  setWindowCentral(window);
}))


// Window Height
keys.push(new Key('\\', alt, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  window.setFrame({
    x: window.frame().x,
    y: window.screen().frameInRectangle().y,
    width: window.frame().width,
    height: window.screen().frameInRectangle().height
  });
  heartbeatWindow(window);
}));

// Window Width
keys.push(new Key('\\', altShift, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  window.setFrame({
    x: window.screen().frameInRectangle().x,
    y: window.frame().y,
    width: window.screen().frameInRectangle().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}));

// Window >
keys.push(new Key('l', altCtrl, function() {
  var window = getCurrentWindow();
  if (!window) return;
  window.setFrame({
    x: window.frame().x + 100,
    y: window.frame().y,
    width: window.frame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}));

// Window <
keys.push(new Key('h', altCtrl, function() {
  var window = getCurrentWindow();
  if (!window) return;
  window.setFrame({
    x: window.frame().x - 100,
    y: window.frame().y,
    width: window.frame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}));

// Window ^
keys.push(new Key('k', altCtrl, function() {
  var window = getCurrentWindow();
  if (!window) return;
  window.setFrame({
    x: window.frame().x,
    y: window.frame().y - 100,
    width: window.frame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}));

// Window v
keys.push(new Key('j', altCtrl, function() {
  var window = getCurrentWindow();
  if (!window) return;
  window.setFrame({
    x: window.frame().x,
    y: window.frame().y + 100,
    width: window.frame().width,
    height: window.frame().height
  });
  heartbeatWindow(window);
}));


// Next Window in One Screen
keys.push(new Key('k', alt, function() {
  var window = getCurrentWindow();
  if (!window) {
    if (Window.recent().length == 0) return;
    Window.recent()[0].focus();
    return;
  }
  restoreMousePositionForWindow(window);
  var targetWindow = getPreviousWindowsOnSameScreen(window);
  if (!targetWindow) {
  return;
  }
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}));

// Previous Window in One Screen 
keys.push(new Key('j', alt, function() {
  var window = getCurrentWindow();
  if (!window) {
    if (Window.recent().length == 0) return;
    Window.recent()[0].focus();
    return;
  }
  restoreMousePositionForWindow(window);

  var targetWindow = getNextWindowsOnSameScreen(window);  // <- most time cost
  if (!targetWindow) {
  return;
  }
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}));



/**
 * My Configuartion Mouse
 */
// Central Mouse
keys.push(new Key('space', alt, function() {
  var window = getCurrentWindow();
  if (!window) return;
  setMousePositionForWindowCenter(window);
}));


/**
 * Mission Control
 */

// use Mac Keyboard setting
// mash + i
// mash + o

// move window to prev space
/*
keys.push(new Key('i', altCtrl, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  if (window.isFullScreen() || window.isMinimized()) return;
  var current = Space.active();
  var allSpaces = Space.all();
  var previous = current.previous();
  if (previous.isFullScreen()) return;
  if (previous.screen().hash() != current.screen().hash()) {
  return;
  }
  if (_.indexOf(_.map(allSpaces, function(x) { return x.hash(); }), previous.hash())
    >= _.indexOf(_.map(allSpaces, function(x) { return x.hash(); }), current.hash())) {
  return;
  }
  current.removeWindows([window]);
  previous.addWindows([window]);
  var prevWindow = getPreviousWindowsOnSameScreen(window);
  if (prevWindow) {
  prevWindow.focus();
  }
}));
*/

// move window to next space
keys.push(new Key('i', altCtrl, function() {
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  if (window.isFullScreen() || window.isMinimized()) return;
  var current = Space.active();
  var allSpaces = Space.all();
  var next = current.next();
  if (next.isFullScreen()) return;
  if (next.screen().hash() != current.screen().hash()) {
  return;
  }
  if (_.indexOf(_.map(allSpaces, function(x) { return x.hash(); }), next.hash())
    <= _.indexOf(_.map(allSpaces, function(x) { return x.hash(); }), current.hash())) {
  return;
  }
  current.removeWindows([window]);
  next.addWindows([window]);
  var nextWindow = getNextWindowsOnSameScreen(window);
  if (nextWindow) {
  nextWindow.focus();
  }
}));


function moveWindowToTargetSpace(window, nextWindow, allSpaces, spaceIndex) {
  var targetSpace = allSpaces[spaceIndex];
  var currentSpace = Space.active();

  currentSpace.removeWindows([window]);
  targetSpace.addWindows([window]);
  if (currentSpace.screen().hash() != targetSpace.screen().hash()) {
    moveToScreen(window, targetSpace.screen());
  }
  if (nextWindow) {
    nextWindow.focus();
    restoreMousePositionForWindow(nextWindow);
  };
};

// move window to park space
/*
keys.push(new Key('delete', alt, function() {
  var isFollow = false;
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  var nextWindow = isFollow ? window : getNextWindowsOnSameScreen(window);
  var allSpaces = Space.all();
  var screenCount = Screen.all().length;
  var parkSpaceIndex = PARK_SPACE_APP_INDEX_MAP[window.app().name()] || PARK_SPACE_INDEX_MAP[screenCount];
  if (parkSpaceIndex >= allSpaces.length) return;
  _.each(window.app().windows(), function(window) {
  moveWindowToTargetSpace(window, nextWindow, allSpaces, parkSpaceIndex);
  });
}));

// move window to work space
keys.push(new Key('return', alt, function() {
  var isFollow = true;
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  var nextWindow = isFollow ? window : getNextWindowsOnSameScreen(window);
  var allSpaces = Space.all();
  var screenCount = Screen.all().length;
  if (WORK_SPACE_INDEX_MAP[screenCount] >= allSpaces.length) return;
  _.each(window.app().windows(), function(window) {
  moveWindowToTargetSpace(window, nextWindow, allSpaces, WORK_SPACE_INDEX_MAP[screenCount]);
  });
}));

// move other window in this space to park space
keys.push(new Key('return', altCtrl, function() {
  var isFollow = false;
  var window = getCurrentWindow();
  if (window === undefined) {
  return;
  }
  var nextWindow = window;
  var allSpaces = Space.all();
  var otherWindowsInSameSpace = _.filter(window.spaces()[0].windows(), function(x) {return x.hash() != window.hash(); });
  var screenCount = Screen.all().length;
  _.each(otherWindowsInSameSpace, function(parkedWindow) {
  var parkSpaceIndex = PARK_SPACE_APP_INDEX_MAP[parkedWindow.app().name()] || PARK_SPACE_INDEX_MAP[screenCount];
  if (parkSpaceIndex >= allSpaces.length) return;
  moveWindowToTargetSpace(parkedWindow, nextWindow, allSpaces, parkSpaceIndex);
  })
}));
*/
