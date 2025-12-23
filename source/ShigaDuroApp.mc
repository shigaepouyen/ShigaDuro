import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ShigaDuroApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        return [ new ShigaDuroView() ];
    }
}

function getApp() as ShigaDuroApp {
    return Application.getApp() as ShigaDuroApp;
}