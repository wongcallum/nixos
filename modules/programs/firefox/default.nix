{
  flake.modules.nixos.firefox =
    { config, lib, ... }:
    {
      programs.firefox = {
        enable = true;
        policies = {
          ExtensionSettings = {
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "force_installed";
            };
            "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
              installation_mode = "force_installed";
            };
            "{9063c2e9-e07c-4c2c-9646-cfe7ca8d0498}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/old-reddit-redirect/latest.xpi";
              installation_mode = "normal_installed";
            };
            "pywalfox@frewacom.org" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
              installation_mode = "normal_installed";
            };
            "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/latest.xpi";
              installation_mode = "normal_installed";
            };
          };
        };

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
