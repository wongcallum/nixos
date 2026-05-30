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
        '';
      };
    };
}
