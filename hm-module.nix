{
  home-manager,
  self,
  name,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    getAttrFromPath
    isPath
    mkIf
    mkOption
    setAttrByPath
    types
    ;

  cfg = getAttrFromPath modulePath config;

  applicationName = "Waterfox";
  modulePath = [
    "programs"
    "waterfox"
  ];

  linuxConfigPath = ".waterfox";
  darwinConfigPath = "Library/Application Support/Waterfox";

  # Actual profile directory path where places.sqlite is located
  profilePath = "${(
    if pkgs.stdenv.isDarwin
    then "${darwinConfigPath}/Profiles"
    else linuxConfigPath
  )}";

  mkFirefoxModule = import "${home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = applicationName;
      wrappedPackageName = "waterfox";
      unwrappedPackageName = "waterfox-unwrapped";
      visible = true;
      platforms = {
        linux = {
          vendorPath = linuxConfigPath;
          configPath = linuxConfigPath;
        };
        darwin = {
          configPath = darwinConfigPath;
          defaultsId = "app.waterfox.waterfox";
        };
      };
    })
  ];

  options = setAttrByPath modulePath {
    extraPrefsFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of extra preference files to be included.";
    };

    extraPrefs = mkOption {
      type = types.str;
      default = "";
      description = "Extra preferences to be included.";
    };

    icon = mkOption {
      type = types.nullOr (types.either types.str types.path);
      default = null;
      description = "Icon to be used for the application. It's only expected to work on Linux.";
    };

    profiles = mkOption {
      type = with types;
        attrsOf (
          submodule (
            {...}: {
              options = {};
            }
          )
        );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.icon == null || pkgs.stdenv.isLinux;
        message = "The 'icon' option is only supported on Linux.";
      }
    ];
    programs.waterfox = {
      package = lib.mkDefault (
        (pkgs.wrapFirefox (self.packages.${pkgs.stdenv.hostPlatform.system}."waterfox-unwrapped".override {
            policies = cfg.policies;
          }) {
            icon = cfg.icon;
          }).override
        {
          extraPrefs = cfg.extraPrefs;
          extraPrefsFiles = cfg.extraPrefsFiles;
          nativeMessagingHosts = cfg.nativeMessagingHosts;
        }
      );

      policies = {
        DisableAppUpdate = lib.mkDefault true;
        DisableTelemetry = lib.mkDefault true;
      };
    };
  };
}
