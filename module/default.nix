# Module factory — receives { hmHelpers, ayatsuriOverlay } from flake.nix
{
  hmHelpers,
  ayatsuriOverlay,
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  inherit (hmHelpers) mkLaunchdService mkMcpOptions mkMcpServerEntry;
  cfg = config.blackmatter.components.ayatsuri;
  isDarwin = pkgs.stdenv.isDarwin;

  # Apply ayatsuri overlay so pkgs.ayatsuri is available
  ayatsuriPkgs = import pkgs.path {
    inherit (pkgs) system;
    overlays = [ ayatsuriOverlay ];
  };

  # Merge theme + wallpaper defaults with user settings (user's explicit options win)
  themeDefaults = {
    options = {
      border_color = cfg.theme.borderColor;
      dim_inactive_color = cfg.theme.dimColor;
    };
  };
  wallpaperDefaults = lib.optionalAttrs (cfg.wallpaper.path != null) {
    options.wallpaper = cfg.wallpaper.path;
  };
  systemDefaultsAttrs = lib.optionalAttrs (cfg.systemDefaults != { }) {
    system_defaults = cfg.systemDefaults;
  };
  mergedSettings = lib.recursiveUpdate
    (lib.recursiveUpdate (lib.recursiveUpdate wallpaperDefaults themeDefaults) systemDefaultsAttrs)
    (if cfg.settings != null then cfg.settings else {});

  # Generate YAML config from nix attrs
  yamlConfig = pkgs.writeText "ayatsuri.yaml" (lib.generators.toYAML { } mergedSettings);

  logDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Logs"
    else
      "${config.home.homeDirectory}/.local/share/ayatsuri/logs";
in
{
  options.blackmatter.components.ayatsuri = {
    enable = mkEnableOption "Ayatsuri — programmable macOS automation framework";

    package = mkOption {
      type = types.package;
      default = ayatsuriPkgs.ayatsuri;
      description = "The ayatsuri package to use.";
    };

    settings = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = ''
        Configuration written to `~/.config/ayatsuri/ayatsuri.yaml`.
        Accepts any attrs that serialize to valid ayatsuri YAML config.
        Figment loads: defaults -> env vars (AYATSURI_*) -> this file.
      '';
      example = {
        options = {
          focus_follows_mouse = true;
          preset_column_widths = [
            0.25
            0.33
            0.5
            0.66
            0.75
          ];
          swipe_gesture_fingers = 4;
          animation_speed = 4000;
          dim_inactive_windows = 0.15;
          border_active_window = true;
          border_color = "#89b4fa";
          border_opacity = 0.9;
          border_width = 2.0;
          border_radius = 10.0;
        };
        bindings = {
          window_focus_west = "cmd - h";
          window_focus_east = "cmd - l";
          window_focus_north = "cmd - k";
          window_focus_south = "cmd - j";
          window_swap_west = "ctrl+alt - h";
          window_swap_east = "ctrl+alt - l";
          window_center = "ctrl+alt - c";
          window_resize = "ctrl+alt - r";
          window_fullwidth = "ctrl+alt - f";
          quit = "ctrl+alt - q";
        };
        windows = {
          pip = {
            title = "picture.*picture";
            floating = true;
          };
        };
        scripting = {
          init_script = "~/.config/ayatsuri/init.rhai";
          script_dirs = [ "~/.config/ayatsuri/scripts" ];
          hot_reload = true;
        };
      };
    };

    wallpaper = {
      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Desktop wallpaper image path (applied on ayatsuri startup).";
        example = "~/Pictures/wallpaper.png";
      };
    };

    theme = {
      borderColor = mkOption {
        type = types.str;
        default = "#88C0D0";
        description = "Active window border color (hex).";
      };
      dimColor = mkOption {
        type = types.str;
        default = "#2E3440";
        description = "Inactive window dim overlay color (hex).";
      };
    };

    systemDefaults = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = ''
        macOS defaults applied by ayatsuri at startup and hot-reload.
        Outer key = domain (e.g. "com.apple.dock"), inner key = preference key.
        Merged into `system_defaults` in the generated YAML config.
      '';
      example = {
        "com.apple.dock" = {
          autohide = true;
          autohide-delay = 0.0;
        };
      };
    };

    scripting = {
      initScript = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Contents of `~/.config/ayatsuri/init.rhai`.
          Main Rhai script loaded on startup.
        '';
        example = ''
          log("ayatsuri init.rhai loaded");
          on_hotkey("cmd-h", || focus_west());
        '';
      };

      extraScripts = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        description = ''
          Additional Rhai scripts written to `~/.config/ayatsuri/scripts/<name>.rhai`.
        '';
        example = {
          "window-rules" = ''
            log("window rules loaded");
          '';
        };
      };

      hotReload = mkOption {
        type = types.bool;
        default = true;
        description = "Enable hot-reload of Rhai scripts on file changes.";
      };
    };

    # ── MCP server options (from substrate hm-service-helpers) ────────
    mcp = mkMcpOptions {
      defaultPackage = cfg.package;
    };
  };

  config = mkIf (cfg.enable && isDarwin) (mkMerge [
    # Install the package
    {
      home.packages = [ cfg.package ];
    }

    # Create log directory
    {
      home.activation.ayatsuri-log-dir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${logDir}"
      '';
    }

    # Launchd agent
    (mkLaunchdService {
      name = "ayatsuri";
      label = "io.pleme.ayatsuri";
      command = "${cfg.package}/bin/ayatsuri";
      args = [ "launch" ];
      logDir = logDir;
      processType = "Interactive";
      keepAlive = true;
    })

    # YAML configuration (figment-based, hot-reloaded on change)
    (mkIf (cfg.settings != null) {
      xdg.configFile."ayatsuri/ayatsuri.yaml".source = yamlConfig;
    })

    # Rhai init script
    (mkIf (cfg.scripting.initScript != "") {
      xdg.configFile."ayatsuri/init.rhai".text = cfg.scripting.initScript;
    })

    # Extra Rhai scripts
    (mkIf (cfg.scripting.extraScripts != { }) {
      xdg.configFile = mapAttrs' (
        name: content: nameValuePair "ayatsuri/scripts/${name}.rhai" { text = content; }
      ) cfg.scripting.extraScripts;
    })

    # MCP server entry (consumed by blackmatter-claude)
    (mkIf cfg.mcp.enable {
      blackmatter.components.ayatsuri.mcp.serverEntry = mkMcpServerEntry {
        command = "${cfg.package}/bin/ayatsuri";
        args = [ "mcp" ];
      };
    })

    # Auto-source theme colors from Stylix when available
    (mkIf (config.lib ? stylix && config.stylix.enable) {
      blackmatter.components.ayatsuri.theme = {
        borderColor = mkDefault "#${config.lib.stylix.colors.base0C}";
        dimColor = mkDefault "#${config.lib.stylix.colors.base00}";
      };
    })
  ]);
}
