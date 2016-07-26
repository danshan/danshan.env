'use strict';

var keys = [];
var alt = ['alt'];
var cmd = ['cmd'];
var cmdAlt = ['cmd', 'alt'];
var altShift = ['alt', 'shift'];
var altCtrl = ['alt', 'ctrl'];


var mousePositions = {};
var ACTIVE_WINDOWS_TIMES = {};
var HIDE_INACTIVE_WINDOW_TIME = 10;  // minitus



/**
 * Utils Functions
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

function sortByMostRecent(windows) {
    var visibleAppMostRecentFirst = _.map(Window.visibleWindowsInOrder(), 
            function(w) { return w.app().name(); });
    var visibleAppMostRecentFirstWithWeight = _.object(visibleAppMostRecentFirst,
                                                     _.range(visibleAppMostRecentFirst.length));
    return _.sortBy(windows, function(window) { 
            return visibleAppMostRecentFirstWithWeight[window.app().name()]; 
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
    var start = new Date().getTime();
    var otherWindowsOnSameScreen = Window.focused().otherWindowsOnSameScreen();  // slow
    Phoenix.log('windowsOnOtherScreen 0.1: ' + (new Date().getTime() - start));
    var otherWindowTitlesOnSameScreen = _.map(otherWindowsOnSameScreen , function(w) { return w.title(); });
    var return_value = _.chain(Window.focused().otherWindowsOnAllScreens())
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
        } 
        return true;
    }).filter(function(window) {
        return now - ACTIVE_WINDOWS_TIMES[window.app().pid]> HIDE_INACTIVE_WINDOW_TIME * 60;
        //return now - ACTIVE_WINDOWS_TIMES[window.app().pid]> 5;
    }).map(function(window) {window.app().hide()});
}

function heartbeatWindow(window) {
    ACTIVE_WINDOWS_TIMES[window.app().pid] = new Date().getTime() / 1000;
    //hide_inactiveWindow(window.otherWindowsOnSameScreen());
}

function getAnotherWindowsOnSameScreen(window, offset) {
    var start = new Date().getTime();
    var windows = window.otherWindowsOnSameScreen(); // slow, makes `Saved spin report for Phoenix version 1.2 (1.2) to /Library/Logs/DiagnosticReports/Phoenix_2015-05-30-170354_majin.spin`
    Phoenix.log('getAnotherWindowsOnSameScreen 1: ' + (new Date().getTime() - start));
    windows.push(window);
    windows = _.chain(windows).sortBy(function(window) {
        return [window.frame().x, window.frame().y, window.app().pid, window.title()].join('_');
    }).value().reverse();
    return windows[(_.indexOf(windows, window) + offset + windows.length) % windows.length];
}

function getNextWindowsOnSameScreen(window) {
    return getAnotherWindowsOnSameScreen(window, -1)
};

function getPreviousWindowsOnSameScreen(window) {
    return getAnotherWindowsOnSameScreen(window, 1)
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
    if (pos.x < rect.x || pos.x > (rect.x + rect.width) || pos.y < rect.y || pos. y > (rect.y + rect.height)) {
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

keys.push(new Key('`', alt, function() { callApp('iTerm'); }));
keys.push(new Key('1', alt, function() { callApp('Google Chrome'); }));
keys.push(new Key('2', alt, function() { callApp('BearyChat'); }));
keys.push(new Key('3', alt, function() { callApp('QQ'); }));
keys.push(new Key('4', alt, function() { callApp('Wechat'); }));
keys.push(new Key('w', alt, function() { callApp('KeePassX'); }));
keys.push(new Key('s', alt, function() { callApp('IntelliJ IDEA 15'); }));
keys.push(new Key('e', alt, function() { callApp('Sublime Text'); }));
keys.push(new Key(',', alt, function() { callApp('Evernote'); }));
keys.push(new Key('.', alt, function() { callApp('Nylas N1'); }));
keys.push(new Key('/', alt, function() { callApp('Finder'); }));
keys.push(new Key(';', alt, function() { callApp('OmniFocus'); }));

/**
 * My Configuartion Screen
 */
// Next screen, now only support 2 display // TODO
keys.push(new Key('l', alt, function() {
  var window = Window.focused();
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
  var window = Window.focused();
  if (!window) return;
  if (window.screen() === window.screen().next()) return;
  if (window.screen().next().frameInRectangle().x > window.screen().frameInRectangle().x) {
    return;
  }
  saveMousePositionForWindow(window);
  var nextScreenWindows = sortByMostRecent(windowsOnOtherScreen());  // find it!!! cost !!!
  if (nextScreenWindows.length > 0) {
    nextScreenWindows[0].focus();
    restoreMousePositionForWindow(nextScreenWindows[0]);
  }
}));

// Window Smaller

keys.push(new Key('-', alt, function() {
  var window = Window.focused();
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
  var window = Window.focused();
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
  var window = Window.focused();
  if (!window) return;
  window.maximize();
  setWindowCentral(window);
}));

// Window Central
keys.push(new Key('m', alt, function() {
  var window = Window.focused();
  if (!window) return;
  setWindowCentral(window);
}))


// Window >
keys.push(new Key('l', altCtrl, function() {
  var window = Window.focused();
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
  var window = Window.focused();
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
  var window = Window.focused();
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
  var window = Window.focused();
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
  var window = Window.focused();
  if (!window) {
    if (Window.visibleWindowsInOrder().length == 0) return;
    Window.visibleWindowsInOrder()[0].focus();
    return;
  }
  saveMousePositionForWindow(window);
  var targetWindow = getNextWindowsOnSameScreen(window);
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}));

// Previous Window in One Screen 
keys.push(new Key('j', alt, function() {
  var window = Window.focused();
  if (!window) {
    if (Window.visibleWindowsInOrder().length == 0) return;
    Window.visibleWindowsInOrder()[0].focus();
    return;
  }
  saveMousePositionForWindow(window);
  var targetWindow = getPreviousWindowsOnSameScreen(window);  // <- most time cost
  targetWindow.focus();
  restoreMousePositionForWindow(targetWindow);
}));

/**
 * My Configuartion Mouse
 */
// Central Mouse
keys.push(new Key('space', alt, function() {
  var window = Window.focused();
  if (!window) return;
  setMousePositionForWindowCenter(window);
}));
