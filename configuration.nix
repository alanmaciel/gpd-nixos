{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./home.nix
  ];

  ########################################
  ## Bootloader / Kernel
  ########################################

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
    configurationLimit = 10;

    # GPD MicroPC: avoid graphical GRUB issues
    gfxmodeEfi = "text";
    gfxpayloadEfi = "text";

    timeoutStyle = "menu";
  };

  # Intel iGPU stability
  boot.kernelParams = [
    "i915.enable_psr=0"
    "i915.enable_fbc=0"

    # Suppress boot messages that overlap login screen
    "quiet"                      # Reduce kernel verbosity
    "systemd.show_status=false"  # Hide systemd service status messages
    "rd.udev.log_level=3"        # Reduce udev messages during boot
    # "udev.log_level=3"           # Reduce udev messages after boot
    # "vt.global_cursor_default=0" # Hide cursor blinking
  ];

  # Not a kernelParam: the kernel module appends its own "loglevel=" derived
  # from this option *after* boot.kernelParams, and the kernel honours the last
  # occurrence on the command line. A literal "loglevel=3" in kernelParams was
  # therefore overridden by the default 4.
  boot.consoleLogLevel = 3;

  # ucsi_acpi exposes no `disable` module parameter, so the old
  # "ucsi_acpi.disable=1" kernel param was a no-op: the module still loaded and
  # spammed `UCSI_GET_PDOS failed (-22)` / `possible UCSI driver bug` on every
  # boot. The GPD MicroPC's USB-C PD controller is not usable through UCSI
  # anyway, so keep the module from being probed at all.
  boot.blacklistedKernelModules = [ "ucsi_acpi" ];

  ########################################
  ## Basic System Settings
  ########################################

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  ########################################
  ## Console (TTY) – large font + gruvbox
  ########################################

  console = {
    earlySetup = true;
    keyMap = "us";

    # Terminus ~24px; very large for the GPD's TTY
    packages = with pkgs; [ terminus_font ];
    font = "ter-u32n";

    # Gruvbox Dark palette (16 ANSI colors)
    # black, red, green, yellow, blue, magenta, cyan, white,
    # brightBlack..brightWhite
    colors = [
      "282828" # 0  black
      "cc241d" # 1  red
      "98971a" # 2  green
      "d79921" # 3  yellow
      "458588" # 4  blue
      "b16286" # 5  magenta
      "689d6a" # 6  cyan
      "a89984" # 7  white
      "928374" # 8  brightBlack
      "fb4934" # 9  brightRed
      "b8bb26" # 10 brightGreen
      "fabd2f" # 11 brightYellow
      "83a598" # 12 brightBlue
      "d3869b" # 13 brightMagenta
      "8ec07c" # 14 brightCyan
      "ebdbb2" # 15 brightWhite
    ];
  };

  ########################################
  ## Wayland + Hyprland
  ########################################

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Top bar
  programs.waybar.enable = true;

  # No services.xserver: the session is Hyprland via greetd, and X11 apps run
  # on the XWayland provided by programs.hyprland.xwayland.enable.
  # videoDrivers and xrandrHeads were X server options, so they go away with
  # it; screen rotation is set by `monitor = DSI-1,...,transform,3` in
  # hyprland.conf.

  # libinput is kept explicit: its default is services.xserver.enable, but the
  # module also installs libinput's udev rules (device quirks), which Hyprland
  # does use. The `touchpad` sub-block is not kept because it only fed
  # services.xserver.inputClassSections; its Wayland equivalent lives in the
  # input block of hyprland.conf.
  services.libinput.enable = true;

  ########################################
  ## Dual Functions keys
  ########################################
  environment.etc."dual-function-keys.yaml".text = ''
    TIMING:
      TAP_MILLISEC: 200

    MAPPINGS:
      # / -> tap '/', hold = Alt
      - KEY: KEY_SLASH
        TAP: KEY_SLASH
        HOLD: KEY_LEFTALT

      # \ -> tap '\', hold = Win/Super
      - KEY: KEY_BACKSLASH
        TAP: KEY_BACKSLASH
        HOLD: KEY_LEFTMETA

      # ↓ -> tap DOWN, hold = Ctrl
      - KEY: KEY_DOWN
        TAP: KEY_DOWN
        HOLD: KEY_LEFTCTRL
  '';

  ########################################
  # interception-tools service
  ########################################
  
  services.interception-tools = {
    enable = true;

    plugins = [
      pkgs.interception-tools-plugins.dual-function-keys
    ];

    # The DEVICE block is mandatory, not optional: udevmon only substitutes
    # $DEVNODE for JOBs attached to a device it matched. Without it the job ran
    # once at startup with an empty $DEVNODE, `uinput -d` died with
    # "option requires an argument -- 'd'", and no intercept process survived —
    # i.e. the remapping below silently did nothing.
    #
    # EV_KEY matches devices capable of emitting all the listed keys, which
    # selects real keyboards and leaves the touchpad/mouse untouched.
    udevmonConfig = ''
      - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE \
             | ${pkgs.interception-tools-plugins.dual-function-keys}/bin/dual-function-keys -c /etc/dual-function-keys.yaml \
             | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_SLASH, KEY_BACKSLASH, KEY_DOWN]
    '';
  };
 
  ########################################
  ## Audio – PipeWire (no sound.enable)
  ########################################

  # PipeWire is the sound server; PulseAudio is disabled
  services.pulseaudio.enable = false;

  # Optional but recommended: ALSA state persistence
  hardware.alsa.enablePersistence = true;

  # Realtime priority for audio
  security.rtkit.enable = true;

  # PipeWire with PulseAudio compatibility and ALSA support
  services.pipewire = {
    enable = true;
    audio.enable = true;

    pulse.enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    # If you ever need JACK:
    # jack.enable = true;

    wireplumber.enable = true;
  };

programs.nix-ld = {
  enable = true;

  # Optional: if you later need specific libs, add them here, for example:
  # libraries = with pkgs; [
  #   stdenv.cc.cc
  #   zlib
  #   openssl
  # ];
};

  ########################################
  ## User
  ########################################

  users.users.alan = {
    isNormalUser = true;
    description = "Alan";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"  # for brightnessctl
      "audio"
      "docker"
    ];
    packages = with pkgs; [
      tree
    ];
  };

  ########################################
  ## System Packages
  ########################################

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    
    # terminal / apps
    alacritty
    pcmanfm
    rofi-wayland

    # tools
    vim
    neovim
    wget
    git
    gh
    pfetch
    gedit
    btop

    # Fn-key helpers + wayland utilities
    brightnessctl
    pamixer
    playerctl
    wl-clipboard
    grim
    slurp
    swappy
    hyprpaper
    adwaita-icon-theme
    xorg.xcursorthemes
    gnome-themes-extra

    # Doom Emacs + deps
    emacs-pgtk
    # Prebuilt epdfinfo for :tools pdf. The package installs it under
    # share/emacs/site-lisp/elpa/pdf-tools-*/epdfinfo, not in bin/, so we
    # symlink it into bin/ to put it on PATH. Exposing only the binary also
    # keeps its elisp from shadowing the copy straight manages.
    (pkgs.runCommand "epdfinfo" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.emacsPackages.pdf-tools}/share/emacs/site-lisp/elpa/pdf-tools-*/epdfinfo $out/bin/epdfinfo
    '')
    ripgrep
    fd
    gnupg

    # :term vterm
    gcc
    # Full clang collides with gcc on bin/cc, bin/c++ and bin/gcov; gcc wins
    # and the rest becomes unreachable. clang-tools provides clangd for
    # :lang cc without clobbering the compiler wrappers.
    clang-tools
    gnumake
    cmake
    libtool

    # :tools lsp → provides npm
    nodejs

    # :lang markdown
    pandoc

    # :lang org
    maim
    scrot
    gnome-screenshot
    graphviz

    # :lang python
    python3Full
    python3Packages.isort
    python3Packages.pytest
    pipenv   # top-level package

    # :lang ruby
    ruby

    # :lang sh
    shellcheck

    # :lang web
    html-tidy
    nodePackages.stylelint
    nodePackages.js-beautify

    chromium
    telegram-desktop
    impala             # Impala package (if available)
    fastfetch          # System info fetch tool
    lazydocker         # TUI for Docker
    localsend          # Local file sharing
    dropbox            # Dropbox sync client
    dropbox-cli        # Dropbox CLI for management
    # pinta              # Paint.NET-like editor
    # tableplus          # Database GUI
  ];

  ########################################
  ## Docker
  ########################################
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  ########################################
  ## Fonts (GUI)
  ########################################

  fonts.packages = with pkgs; [
    jetbrains-mono
    font-awesome
    terminus_font
    nerd-fonts.iosevka
    nerd-fonts.blex-mono
    nerd-fonts.overpass
  ];

  ########################################
  ## SSH
  ########################################

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true;
      # UseDns = true does a reverse lookup per connection and adds latency
      # (or timeouts) at login when DNS can't resolve the source IP.
      UseDns = false;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  ########################################
  ## Firewall
  ########################################

  # openssh already opens 22. LocalSend needs 53317 on TCP (transfer) and UDP
  # (multicast discovery) to see other machines on the LAN.
  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };

  ########################################
  ## Intel GPU Stack
  ########################################

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # iHD; covers the GPD MicroPC's Gemini Lake (Gen9 LP)
      intel-media-driver
    ];
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";

    # GTK does not support fractional scaling through env vars: GDK_SCALE is
    # parsed as an integer, so "1.10" was read as 1 and did nothing. The real
    # scaling is applied by the compositor via `monitor = DSI-1,...,1.25` in
    # hyprland.conf.
    GDK_DPI_SCALE = "1";

    # No QT_SCALE_FACTOR or QT_FONT_DPI: under Wayland the compositor already
    # hands the scale factor to Qt apps, so these variables multiplied on top
    # of the monitor's 1.25 (1.25 * 1.10 = 1.375, and QT_FONT_DPI 110/96
    # scaled the font again up to ~1.58).
    # The only place scaling is adjusted is the `monitor` line in
    # hyprland.conf.

    # Cursors (for apps that read env, though Hyprland also has env= lines)
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE  = "28";

    # XDG_SESSION_TYPE is set by logind based on the actual session; forcing
    # it here lied in X11 sessions. GDK_BACKEND=wayland breaks GTK apps under
    # X11, so it is now set only inside Hyprland (env= in hyprland.conf).
  };

  ########################################
  ## Greetd – TUIGreet + Hyprland only
  ########################################

  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        command = let
          # Supports both new nixpkgs (pkgs.tuigreet)
          # and old ones (pkgs.greetd.tuigreet)
          tuigreetPkg = pkgs.tuigreet or pkgs.greetd.tuigreet;
        in ''
          ${tuigreetPkg}/bin/tuigreet \
	    --greeting "Welcome, log in to begin" \
            --time \
            --remember \
            --remember-user-session \
            --asterisks \
            --cmd Hyprland
        '';
        user = "greeter";
      };
    };
  };

  # /etc/greetd/environments is no longer needed for tuigreet, so the
  # environment.etc."greetd/environments" block is gone

  ########################################
  ## xdg-portal (Wayland)
  ########################################

  xdg.portal = {
    enable = true;

    # Note: this does NOT disable the GTK portal, despite what the previous
    # comment here claimed. xdg-desktop-portal-gtk is still installed and is
    # still used — and that is what we want: hyprland's portal implements
    # Screenshot/ScreenCast but not FileChooser or Settings, so without the GTK
    # backend file pickers in GTK apps would have no portal to talk to.
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
    ];

    # configPackages installs hyprland-portals.conf, whose `default=hyprland;gtk`
    # sets the preference order: hyprland answers first, GTK picks up whatever
    # hyprland does not implement.
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  ########################################
  ## Nix store housekeeping
  ########################################

  # GRUB already limits the menu to 10 entries, but that does not delete the
  # generations: without GC the store grows indefinitely on a small disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Deduplicates identical store files via hard links.
  nix.optimise.automatic = true;

  ########################################
  ## NixOS State Version
  ########################################

  system.stateVersion = "24.11";
}
