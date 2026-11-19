// Frost Screen Time: tell the tracker which app is active. Loaded by
// `frost-screentime daemon`; sends only the app's class and desktop file name.
function report(w) {
    callDBus("org.frost.ScreenTime", "/", "org.frost.ScreenTime", "Activate",
             w ? String(w.resourceClass || "") : "",
             w ? String(w.desktopFileName || "") : "");
}
workspace.windowActivated.connect(report);
report(workspace.activeWindow);
