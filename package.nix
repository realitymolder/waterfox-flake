{
  name,
  variant,
  icon ? null,
  policies ? {},
  lib,
  stdenv,
  config,
  wrapGAppsHook3,
  autoPatchelfHook,
  ffmpeg_7,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  libva,
  libGL,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  undmg,
  writeText,
  fetchurl,
  fetchzip,
  makeDesktopItem,
  copyDesktopItems,
   patchelfUnstable, # Required for Firefox-based patching (--no-clobber-old-sections)
  applicationName ? "Waterfox",
}: let
  binaryName = "waterfox";

  libName = "waterfox-bin-${variant.version}";

  mozillaPlatforms = {
    x86_64-linux = "linux-x86_64";
    aarch64-darwin = "darwin-aarch64";
  };

  firefoxPolicies =
    (config.firefox.policies or {})
    // policies;

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON {policies = firefoxPolicies;});

  pname = "waterfox-${name}-bin-unwrapped";

  desktopIconName = binaryName;

  installDarwin = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -r *.app "$out/Applications/${applicationName}.app"
    ln -s waterfox "$out/Applications/${applicationName}.app/Contents/MacOS/${binaryName}"

    # Install policies.json for macOS
    mkdir -p "$out/Applications/${applicationName}.app/Contents/Resources/distribution"
    ln -s ${policiesJson} "$out/Applications/${applicationName}.app/Contents/Resources/distribution/policies.json"

    # Re-sign with correct identifier to maintain compatibility
    /usr/bin/codesign --force --deep --sign - \
      --identifier "app.waterfox.waterfox" \
      "$out/Applications/${applicationName}.app"

    # Use symlink path to avoid installs.ini accumulation on Nix rebuilds
    # The symlink is created by home-manager and remains stable across rebuilds
    cat > "$out/bin/${binaryName}" << EOF
    #!/bin/bash
    # Use stable path from home-manager to avoid creating new install IDs
    STABLE_PATH="\$HOME/Applications/Home Manager Apps/${applicationName}.app"
    if [[ -e "\$STABLE_PATH" ]]; then
      exec /usr/bin/open -na "\$STABLE_PATH" --args "\$@"
    else
      # Fallback to nix store path if symlink doesn't exist yet
      exec /usr/bin/open -na "$out/Applications/${applicationName}.app" --args "\$@"
    fi
    EOF

    chmod +x "$out/bin/${binaryName}"
    ln -s "$out/bin/${binaryName}" "$out/bin/waterfox"

    runHook postInstall
  '';

  installLinux = ''
    runHook preInstall

    # Linux tarball installation
    mkdir -p "$out/lib/${libName}"
    cp -r "$src"/* "$out/lib/${libName}"

    mkdir -p "$out/bin"
    ln -s "$out/lib/${libName}/waterfox" "$out/bin/${binaryName}"

    mkdir -p "$out/lib/${libName}/distribution"
    ln -s ${policiesJson} "$out/lib/${libName}/distribution/policies.json"

    install -D $src/browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/${desktopIconName}.png
    install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/${desktopIconName}.png

    runHook postInstall
  '';
in
  stdenv.mkDerivation {
    inherit pname;
    inherit (variant) version;

    src =
      if stdenv.hostPlatform.isDarwin
      then
        fetchurl {
          inherit (variant) url;
          hash = variant.sha256;
        }
      else
        fetchzip {
          inherit (variant) url;
          hash = variant.sha256;
        };

    sourceRoot = lib.optionalString stdenv.hostPlatform.isDarwin ".";

    desktopItems = [
      (makeDesktopItem {
        name = binaryName;
        desktopName = "Waterfox";
        exec = "${binaryName} %u";
        icon =
          if icon != null && (lib.isString icon || lib.isPath icon)
          then icon
          else desktopIconName;
        type = "Application";
        mimeTypes = [
          "text/html"
          "text/xml"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "application/x-xpinstall"
          "application/pdf"
          "application/json"
        ];
        startupWMClass = binaryName;
        categories = ["Network" "WebBrowser"];
        startupNotify = true;
        terminal = false;
        keywords = ["Internet" "WWW" "Browser" "Web" "Explorer"];
        extraConfig.X-MultipleArgs = "false";

        actions = {
          new-windows = {
            name = "Open a New Window";
            exec = "${binaryName} %u";
          };
          new-private-window = {
            name = "Open a New Private Window";
            exec = "${binaryName} --private-window %u";
          };
          profilemanager = {
            name = "Open the Profile Manager";
            exec = "${binaryName} --ProfileManager %u";
          };
        };
      })
    ];
    nativeBuildInputs =
      lib.optionals stdenv.hostPlatform.isLinux [
        wrapGAppsHook3
        autoPatchelfHook
        patchelfUnstable
        copyDesktopItems
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        undmg
      ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libXtst
      ffmpeg_7
    ];

    runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
      curl
      libva.out
      pciutils
      libGL
    ];

    appendRunpaths = lib.optionals stdenv.hostPlatform.isLinux [
      "${libGL}/lib"
      "${pipewire}/lib"
    ];

    # Firefox uses "relrhack" to manually process relocations from a fixed offset
    patchelfFlags = ["--no-clobber-old-sections"];

    preFixup = lib.optionals stdenv.hostPlatform.isLinux ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ffmpeg_7]}"
        --set MOZ_APP_NAME ${binaryName}
        --add-flags "--name=''${MOZ_APP_LAUNCHER:-${binaryName}}"
        --add-flags "--class=''${MOZ_APP_LAUNCHER:-${binaryName}}"
      )
    '';

    installPhase =
      if stdenv.hostPlatform.isDarwin
      then installDarwin
      else installLinux;

    passthru = {
      inherit applicationName binaryName libName;
      ffmpegSupport = true;
      gssSupport = false;
      gtk3 = gtk3;
    };

    meta = {
      description = "A privacy-focused Firefox-based browser";
      homepage = "https://www.waterfox.com";
      downloadPage = "https://www.waterfox.com/download/";
      changelog = "https://github.com/BrowserWorks/Waterfox/releases";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = builtins.attrNames mozillaPlatforms;
      hydraPlatforms = [];
      mainProgram = binaryName;
      desktopFileName = "${binaryName}.desktop";
    };
  }
