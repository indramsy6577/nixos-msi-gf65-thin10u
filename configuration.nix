{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Host & Network
  networking.hostName = "ctrlaltfocus";
  networking.networkmanager.enable = true;

  # Locale & Time
  time.timeZone = "Asia/Jakarta";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Display manager & desktop (GNOME Wayland)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Printing
  services.printing.enable = true;

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire = {
      "context.properties" = {
        "link.max-buffers" = 16;
        "log.level" = 2;
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
        "core.daemon" = true;
        "core.name" = "pipewire-0";
      };
      "context.modules" = [
        { name = "libpipewire-module-protocol-native"; args = {}; flags = [ "ifexists" "nofail" ]; }
        { name = "libpipewire-module-portal"; flags = [ "ifexists" "nofail" ]; }
        { name = "libpipewire-module-access"; args = {}; }
      ];
    };
  };

  # User
  users.users.focus = {
    isNormalUser = true;
    description = "Control Alternative Focus";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  security.sudo.extraRules = [{
    users = [ "focus" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # ACME (Cloudflare DNS)
  security.acme = {
    acceptTerms = true;
    defaults.email = "focus@ctrlaltfocus.web.id";
    certs."focus.ctrlaltfocus.web.id" = {
      dnsProvider = "cloudflare";
      credentialsFile = "/etc/secrets/cf.env";
      dnsPropagationCheck = true;
    };
  };

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      # Paksa OBS link ke ffmpeg-full (NVENC)
      obs-studio = prev.obs-studio.override { ffmpeg = prev.ffmpeg-full; };
    })
  ];

  environment.systemPackages = with pkgs; [
    curl
    # screenshot
    flameshot
    (pkgs.writeShellScriptBin "flameshot-wayland" ''
      #!/bin/sh
      env XDG_CURRENT_DESKTOP=GNOME \
          QT_QPA_PLATFORM=wayland \
          flameshot "$@"
    '')
    satty

    # Wayland/Qt bits
    qt6.qtwayland
    qt5.qtwayland

    # dev & utils
    git
    google-chrome
    htop
    nix-ld
    obs-studio
    ffmpeg-full
    nvidia-vaapi-driver
    pavucontrol
    podman
    podman-compose
    podman-desktop
    remmina
    vim
    vscode-with-extensions
    wget
    winbox4

    # test GPU
    pciutils
    mesa-demos
    vulkan-tools

    # terminal utils
    zip
    unzip

    # PRIME offload wrapper
    (pkgs.writeShellScriptBin "nvidia-offload" ''
      exec env \
        __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __VK_LAYER_NV_optimus=NVIDIA_only \
        "$@"
    '')

    # OBS NVENC launcher
    (pkgs.writeShellScriptBin "obs-nv" ''
      export LIBVA_DRIVER_NAME=nvidia
      export NVD_BACKEND=direct
      export __GL_GSYNC_ALLOWED=0
      export __GL_VRR_ALLOWED=0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export LIBGL_ALWAYS_SOFTWARE=0

      export GDK_BACKEND=wayland
      export QT_QPA_PLATFORM=wayland
      export XDG_SESSION_TYPE=wayland

      export PIPEWIRE_RUNTIME_DIR="/run/user/$(id -u)/pipewire-0"
      export PIPEWIRE_LATENCY=128/48000
      export PIPEWIRE_QUANTUM=1024
      export PWR_DEBUG=3

      export OBS_USE_EGL=1
      export OBS_VKCAPTURE=1
      export OBS_RESETCAPTURE=1
      export XDG_CURRENT_DESKTOP=GNOME

      if [ -n "$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:/usr/lib/nvidia:/usr/lib:$LD_LIBRARY_PATH"
      else
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:/usr/lib/nvidia:/usr/lib"
      fi

      nvidia-offload obs "$@"
    '')

    (makeDesktopItem {
      name = "obs-nv";
      desktopName = "OBS Studio (NVIDIA)";
      genericName = "Recording/Streaming";
      exec = "obs-nv";
      icon = "com.obsproject.Studio";
      comment = "Free and open source software for video recording and live streaming";
      categories = [ "AudioVideo" "Recorder" ];
      terminal = false;
    })
  ];

  # === ALIAS: 'obs' -> 'obs-nv' ===
  environment.shellAliases = {
    obs = "obs-nv";
    # Bonus kalau mau start silent langsung rekam:
    obs-record = "obs-nv --startrecording --minimize-to-tray";
  };

  # ===== Intel + NVIDIA (Hybrid Offload di Wayland) =====
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;

    prime = {
      offload.enable = true;
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Grafis & VA-API (Intel iGPU decode)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Wayland env
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";

    # Qt Wayland
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # NVIDIA Wayland
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBGL_ALWAYS_SOFTWARE = "0";

    # Desktop environment
    XDG_CURRENT_DESKTOP = "GNOME";
    XDG_SESSION_DESKTOP = "gnome";
    SDL_VIDEODRIVER = "wayland";
  };

  programs.nix-ld.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # Power
  services.upower.enable = true;
  services."power-profiles-daemon".enable = true;

  # Firewall
  networking.firewall.enable = false;

  # Portal (pakai modul, bukan install manual)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  system.stateVersion = "25.05";
}
