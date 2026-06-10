{
  flake.modules.nixos.firefox =
    { config, lib, ... }:
    {
      programs.firefox = {
        enable = true;
        preferences = lib.mkMerge [
          {
            "browser.fixup.domainsuffixwhitelist.${config.modules.gateway.tld}" = true;
            "browser.download.panel.shown" = true;
            "browser.search.suggest.enable" = false;
            "browser.urlbar.suggest.searches" = false;
            "browser.ml.linkPreview.enabled" = false;
            "browser.ai.control.default" = "blocked";
            "browser.urlbar.showSearchTerms.enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "browser.uidensity" = 1; # compact
          }
          (lib.optionalAttrs config.modules.fonts.enable {
            "font.name.serif.x-western" = "HarmonyOS Sans TC";
          })
        ];
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

          // Load userChrome.css
          try {
            let sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
            let ios = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
            let uri = ios.newURI("file://${./userChrome.css}");
            if (!sss.sheetRegistered(uri, sss.USER_SHEET)) {
              sss.loadAndRegisterSheet(uri, sss.USER_SHEET);
            }
          } catch (ex) {
            Cu.reportError(ex.message);
          }
        '';
      };
    };
}
