# Waterfox

This is a nix flake for the Waterfox browser.

## Features

- Linux and macOS support
- Available for _x86_64_ on Linux and _aarch64_ on macOS
- **Note**: aarch64-linux is not supported by Waterfox
- [Policies can be modified via Home Manager and unwrapped package override](#policies)
- Fast & Automatic updates via GitHub Actions
- Browser update checks are disabled by default

## Installation

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  waterfox = {
    url = "github:realitymolder/waterfox-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };
  # ...
}
```

### Integration

<details>
<summary><h4>Home Manager</h4></summary>

```nix
{
  # home.nix
  imports = [
    inputs.waterfox.homeModules.waterfox
  ];

  programs.waterfox.enable = true;
}
```

Then build your Home Manager configuration

```shell
$ home-manager switch
```

Check the [Home Manager Reference](#home-manager-reference) and my rice
[here](https://github.com/luisnquin/nixos-config/blob/main/home/modules/programs/browser/zen.nix)!
:)

</details>

<details>
<summary><h4>With environment.systemPackages or home.packages</h4></summary>

To integrate `Waterfox` to your NixOS/Home Manager configuration, add the
following to your `environment.systemPackages` or `home.packages`:

```nix
# supported systems: 'x86_64-linux' and 'aarch64-darwin'

inputs.waterfox.packages."${system}".default

# you can even override the package policies
inputs.waterfox.packages."${system}".default.override {
  policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      # more and more
  };
}
```

Afterwards you can just build your configuration

```shell
$ sudo nixos-rebuild switch # or home-manager switch
```

</details>

### Start the browser

```shell
$ waterfox
```

## Home Manager reference

This is only an attempt to document some of the options provided by the
[mkFirefoxModule](https://github.com/nix-community/home-manager/blob/67f60ebce88a89939fb509f304ac554bcdc5bfa6/modules/programs/firefox/mkFirefoxModule.nix#L207)
module, so feel free to experiment with other program options and help with
further documentation.

`programs.waterfox.*`

- `enable` (_boolean_): Enable the home manager config.

- `nativeMessagingHosts` (listOf package): To
  [enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).

  **Example:**

  ```nix
  {
    # Add any other native connectors here
    programs.waterfox.nativeMessagingHosts = [pkgs.firefoxpwa];
  }
  ```

- `policies` (attrsOf anything):

> [!IMPORTANT]\
> If you're on macOS you'll need to configure
> [programs.waterfox.darwinDefaultsId](https://home-manager-options.extranix.com/?query=programs.firefox.darwinDefaultsId&release=master)
> first.

### Some common policies

```nix
{
  programs.waterfox.policies = {
    AutofillAddressEnabled = true;
    AutofillCreditCardEnabled = false;
    DisableAppUpdate = true;
    DisableFeedbackCommands = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableTelemetry = true;
    DontCheckDefaultBrowser = true;
    NoDefaultBookmarks = true;
    OfferToSaveLogins = false;
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Cryptomining = true;
      Fingerprinting = true;
    };
  };
}
```

For more policies [read this](https://mozilla.github.io/policy-templates/).

- profiles:
  - [extensions](#extensions)
  - [search](#search)
  - [preferences](#preferences)
  - [bookmarks](#bookmarks)
  - [userChrome](#userchromecss)

### Extensions

You can use [rycee's firefox-addons](https://nur.nix-community.org/repos/rycee/)
like this:

```nix
inputs = {
  firefox-addons = {
    url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
{
  programs.waterfox.profiles.*.extensions.packages =
     with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
          ublock-origin
          dearrow
          proton-pass
          ...
        ];
    ];
}
```

You can search for package names by going to
[the NUR website](https://nur.nix-community.org/repos/rycee/)

> [!IMPORTANT]
> Depending on how your flake is configured, you might not be able to install
> extensions marked "unfree" like [improved-tube](https://improvedtube.com/).
> For those extensions, the only way to install them is through the firefox
> store
>
> If you are not using the
> [fireox-addons](https://nur.nix-community.org/repos/rycee/) repo, your
> configuration will still build with the configuration, but the extension will
> not install.\
> Doing so through the repo will throw a build error warning you about the
> package being unfree

### Search

[Search Engine Aliases](https://github.com/nix-community/home-manager/blob/master/modules/programs/firefox/profiles/search.nix#L211)

```nix
{
   programs.waterfox.profiles.*.search = {
        force = true; # Needed for nix to overwrite search settings on rebuild
        default = "ddg"; # Aliased to duckduckgo, see other aliases in the link above
        engines = {
            # My nixos Option and package search shortcut
          mynixos = {
            name = "My NixOS";
            urls = [
              {
                template = "https://mynixos.com/search?q={searchTerms}";
                params = [
                  {
                    name = "query";
                    value = "searchTerms";
                  }
                ];
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@nx"]; # Keep in mind that aliases defined here only work if they start with "@"
          };
        };
      };

}
```

### Preferences

```nix
{
  programs.waterfox.profiles.*.settings = {
    "browser.tabs.warnOnClose" = false;
    "browser.download.panel.shown" = false;
    # Since this is a json value, it can be nixified and translated by home-manager;
    browser = {
      tabs.warnOnClose = false;
      download.panel.shown = false;
    };
    # Find all settings in about:config
  };
}
```

### Bookmarks

```nix
{
   programs.waterfox.profiles.*.bookmarks = {
        force = true; # Required for nix to overwrite bookmarks on rebuild
        settings = [
          {
            name = "Nix sites";
            toolbar = true;
            bookmarks = [
              {
                name = "homepage";
                url = "https://nixos.org/";
              }
              {
                name = "wiki";
                tags = ["wiki" "nix"];
                url = "https://wiki.nixos.org/";
              }
            ];
          }
        ];
      };
}
```

### userChrome.css

```nix
{
  programs.waterfox.profiles.*.userChrome = ''
    #navigator-toolbox {
      background-color: #2b2b2b; /* Changes the toolbar background color */
    }
  '';
}
```

[Artile on how to costumize userChrome](https://mefmobile.org/how-to-customize-firefoxs-user-interface-with-userchrome-css/)

## 1Password

Waterfox has to be manually added to the list of browsers that 1Password will
communicate with. See [this wiki article](https://wiki.nixos.org/wiki/1Password)
for more information. To enable 1Password integration, you need to add the
browser identifier to the file `/etc/1password/custom_allowed_browsers`.

```nix
environment.etc = {
  "1password/custom_allowed_browsers" = {
    text = ''
      .waterfox-wrapped
    ''; # or just "waterfox" if you use unwrapped package
    mode = "0755";
  };
};
```

## Native Messaging

To
[enable communication between the browser and native applications](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging),
you can use the following configuration pattern.

### With Home Manager

Check the [Home Manager Reference](#home-manager-reference).

### With package override

```nix
{
  home.packages = [
    (
      inputs.waterfox.packages."${system}".default.override {
        nativeMessagingHosts = [pkgs.firefoxpwa];
      }
    )
  ];
}
```

## Bonus

### XDG MIME Associations

To set Zen Browser as the default application for various file types and URL
schemes, you can add the following configuration to your Home Manager setup:

```nix
{
  xdg.mimeApps = let
    value = let
      waterfox = inputs.waterfox.packages.${system}.default;
    in
      waterfox.meta.desktopFileName;

    associations = builtins.listToAttrs (map (name: {
        inherit name value;
      }) [
        "application/x-extension-shtml"
        "application/x-extension-xhtml"
        "application/x-extension-html"
        "application/x-extension-xht"
        "application/x-extension-htm"
        "x-scheme-handler/unknown"
        "x-scheme-handler/mailto"
        "x-scheme-handler/chrome"
        "x-scheme-handler/about"
        "x-scheme-handler/https"
        "x-scheme-handler/http"
        "application/xhtml+xml"
        "application/json"
        "text/plain"
        "text/html"
      ]);
  in {
    associations.added = associations;
    defaultApplications = associations;
  };
}
```

## Troubleshooting

#### Waterfox not seeing my GPU

Make sure that you update your flake.lock as to sync up nixpkgs version. Or make
waterfox follow your system nixpkgs by using `inputs.nixpkgs.follows = "nixpkgs"`
(assuming your nixpkgs input is named nixpkgs).

#### 1Password constantly requires password

You may want to set `policies.DisableAppUpdate = false;` in your policies.json
file.

## Contributing

Before contributing, please make sure that your code is formatted correctly by
running

```shell
$ nix fmt
```

## LICENSE

This project is licensed under the [MIT License](./LICENSE).
