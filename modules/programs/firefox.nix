{
  flake.modules.nixos.firefox = {
    programs.firefox = {
      enable = true;
      autoConfig = ''
        // Any comment. You must start the file with a single-line comment!
        var { classes: Cc, interfaces: Ci, utils: Cu } = Components;

        // Set new tab page
        try {
          ChromeUtils.importESModule(
            "resource:///modules/AboutNewTab.sys.mjs",
          ).AboutNewTab.newTabURL = "https://prism.tower.7sref";
        } catch (e) {
          Cu.reportError(e);
        } // report errors in the Browser Console

        // Auto focus new tab content
        try {
          const { BrowserWindowTracker } = ChromeUtils.importESModule(
            "resource:///modules/BrowserWindowTracker.sys.mjs",
          );
          const Services = globalThis.Services;
          Services.obs.addObserver((event) => {
            window = BrowserWindowTracker.getTopWindow();
            window.gBrowser.selectedBrowser.focus();
          }, "browser-open-newtab-start");
        } catch (e) {
          Cu.reportError(e);
        }
      '';
    };
  };
}
