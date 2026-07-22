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
    "ucsi_acpi.disable=1"

    # Suppress boot messages that overlap login screen
    "quiet"                      # Reduce kernel verbosity
    "loglevel=3"                 # Only show errors (3) or warnings+ (4)
    "systemd.show_status=false"  # Hide systemd service status messages
    "rd.udev.log_level=3"        # Reduce udev messages during boot
    # "udev.log_level=3"           # Reduce udev messages after boot
    # "vt.global_cursor_default=0" # Hide cursor blinking
  ];

  ########################################
  ## Basic System Settings
  ########################################

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  ########################################
  ## Console (TTY) – fuente grande + gruvbox
  ########################################

  console = {
    earlySetup = true;
    keyMap = "us";

    # Terminus 24px aprox; muy grande para TTY del GPD
    packages = with pkgs; [ terminus_font ];
    font = "ter-u32n";

    # Paleta Gruvbox Dark (16 colores ANSI)
    # negro, rojo, verde, amarillo, azul, magenta, cyan, blanco,
    # brightNegro..brightBlanco
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

  # Sin services.xserver: la sesión es Hyprland vía greetd y las apps X11
  # corren sobre el XWayland que aporta programs.hyprland.xwayland.enable.
  # videoDrivers y xrandrHeads eran opciones del servidor X, así que se van
  # con él; la rotación de pantalla la define `monitor = DSI-1,...,transform,3`
  # en hyprland.conf.

  # libinput se mantiene explícito: su default es services.xserver.enable, pero
  # el módulo también instala las reglas udev de libinput (quirks de
  # dispositivos), que Hyprland sí usa. El sub-bloque `touchpad` no se conserva
  # porque solo alimentaba services.xserver.inputClassSections; su equivalente
  # en Wayland vive en el bloque input de hyprland.conf.
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

    # Sin filtros de DEVICE para que funcione seguro en todo teclado
    udevmonConfig = ''
      - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE \
             | ${pkgs.interception-tools-plugins.dual-function-keys}/bin/dual-function-keys -c /etc/dual-function-keys.yaml \
             | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
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

  # Opcional: si luego necesitas libs específicas, las agregas aquí, por ejemplo:
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
    # epdfinfo precompilado para :tools pdf. El paquete lo instala en
    # share/emacs/site-lisp/elpa/pdf-tools-*/epdfinfo, no en bin/, así que lo
    # enlazamos a bin/ para que quede en PATH. Exponer solo el binario evita
    # además que su elisp ensombrezca la copia que maneja straight.
    (pkgs.runCommand "epdfinfo" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.emacsPackages.pdf-tools}/share/emacs/site-lisp/elpa/pdf-tools-*/epdfinfo $out/bin/epdfinfo
    '')
    ripgrep
    fd
    gnupg

    # :term vterm
    gcc
    # clang completo colisiona con gcc en bin/cc, bin/c++ y bin/gcov; gcc gana
    # y el resto queda inaccesible. clang-tools aporta clangd para :lang cc
    # sin pisar los wrappers del compilador.
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
      # UseDns = true hace un reverse lookup por conexión y añade latencia
      # (o timeouts) al login cuando el DNS no resuelve la IP de origen.
      UseDns = false;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  ########################################
  ## Firewall
  ########################################

  # openssh ya abre el 22. LocalSend necesita 53317 en TCP (transferencia)
  # y UDP (descubrimiento por multicast) para verse con otros equipos de la LAN.
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
      # iHD; cubre Gemini Lake (Gen9 LP) del GPD MicroPC
      intel-media-driver
    ];
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";

    # GTK no soporta escalado fraccionario por env: GDK_SCALE se parsea como
    # entero, así que "1.10" se leía como 1 y no hacía nada. El escalado real
    # lo aplica el compositor vía `monitor = DSI-1,...,1.25` en hyprland.conf.
    GDK_DPI_SCALE = "1";

    # Nada de QT_SCALE_FACTOR ni QT_FONT_DPI: bajo Wayland el compositor ya
    # entrega el factor de escala a las apps Qt, así que estas variables se
    # multiplicaban encima del 1.25 del monitor (1.25 * 1.10 = 1.375, y
    # QT_FONT_DPI 110/96 volvía a escalar la fuente hasta ~1.58).
    # El único sitio donde se ajusta el escalado es la línea `monitor` de
    # hyprland.conf.

    # Cursors (for apps that read env, though Hyprland also has env= lines)
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE  = "28";

    # XDG_SESSION_TYPE lo define logind según la sesión real; forzarlo aquí
    # mentía en sesiones X11. GDK_BACKEND=wayland rompe apps GTK bajo X11,
    # así que ahora se define solo dentro de Hyprland (env= en hyprland.conf).
  };

  ########################################
  ## Greetd – solo TUIGreet + Hyprland
  ########################################

  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        command = let
          # Soporta tanto nixpkgs nuevos (pkgs.tuigreet)
          # como viejos (pkgs.greetd.tuigreet)
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

  # Clear TTY before greetd starts
  # systemd.services.greetd = {
  #   serviceConfig = {
  #     Type = "idle";
  #   };
  # };

  # Ya no necesitamos /etc/greetd/environments para tuigreet,
  # así que se elimina el bloque environment.etc."greetd/environments"

  ########################################
  ## xdg-portal (Wayland)
  ########################################

  xdg.portal = {
    enable = true;

    # Disable GTK portal (creates long delays)
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
    ];

    # Prevent GTK portal from loading
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  ########################################
  ## Nix store housekeeping
  ########################################

  # El GRUB ya limita el menú a 10 entradas, pero eso no borra las
  # generaciones: sin GC el store crece indefinidamente en un disco chico.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Deduplica archivos idénticos del store por hard link.
  nix.optimise.automatic = true;

  ########################################
  ## NixOS State Version
  ########################################

  system.stateVersion = "24.11";
}
