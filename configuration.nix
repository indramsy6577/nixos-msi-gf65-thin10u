{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ctrlaltfocus";
  networking.networkmanager.enable = true;

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

  # Display manager & desktop (Pure Wayland)
  services.xserver.enable = false;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

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
        {
          name = "libpipewire-module-protocol-native";
          args = {};
          flags = [ "ifexists" "nofail" ];
        }
        {
          name = "libpipewire-module-portal";
          flags = [ "ifexists" "nofail" ];
        }
        {
          name = "libpipewire-module-access";
          args = {};
        }
      ];
    };
  };

  users.users.focus = {
    isNormalUser = true;
    description = "Control Alternative Focus";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [ ];
  };

  security.sudo.extraRules = [{
    users = ["focus"];
    commands = [{ command = "ALL"; options = ["NOPASSWD"]; }];
  }];

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
      # Paksa OBS link ke ffmpeg-full (punya NVENC)
      obs-studio = prev.obs-studio.override { ffmpeg = prev.ffmpeg-full; };
    })
  ];

  environment.systemPackages = with pkgs; [
    curl
    #screnshot
    flameshot
    (pkgs.writeShellScriptBin "flameshot-wayland" ''
      #!/bin/sh
      env XDG_CURRENT_DESKTOP=Gnome \
          QT_QPA_PLATFORM=wayland \
          flameshot "$@"
    '')
    satty
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    gnome-settings-daemon
    glib
    qt6.qtwayland
    qt5.qtwayland
    git
    google-chrome
    htop
    nix-ld
    #obs apps
    obs-studio
    ffmpeg-full
    nvidia-vaapi-driver
    pipewire
    xdg-desktop-portal-wlr
    (pkgs.writeShellScriptBin "obs-nv" ''
      # Set up NVIDIA environment
      export LIBVA_DRIVER_NAME=nvidia
      export NVD_BACKEND=direct
      export __GL_GSYNC_ALLOWED=0
      export __GL_VRR_ALLOWED=0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export LIBGL_ALWAYS_SOFTWARE=0
      
      # Wayland setup
      export GDK_BACKEND=wayland
      export QT_QPA_PLATFORM=wayland
      export XDG_SESSION_TYPE=wayland
      
      # PipeWire configuration
      export PIPEWIRE_RUNTIME_DIR="/run/user/$(id -u)/pipewire-0"
      export PIPEWIRE_LATENCY=128/48000
      export PIPEWIRE_QUANTUM=1024
      export PWR_DEBUG=3
      
      # OBS specific
      export OBS_USE_EGL=1
      export OBS_VKCAPTURE=1
      export OBS_RESETCAPTURE=1
      export XDG_CURRENT_DESKTOP=gnome
      
      # Set up library path for NVENC
      if [ -n "$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:/usr/lib/nvidia:/usr/lib:$LD_LIBRARY_PATH"
      else
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:/usr/lib/nvidia:/usr/lib"
      fi
      
      # Run OBS with NVIDIA
      nvidia-offload obs "$@"
    '')
    pavucontrol
    #container apps
    podman
    podman-compose
    podman-desktop
    #remote desktop apps
    remmina
    vim
    vscode-with-extensions
    wget
    winbox4
    #wayland apps
    qt6.qtwayland
    #test vga
    pciutils            # lspci
    mesa-demos          # glxinfo/glxgears
    vulkan-tools        # vulkaninfo
    # terminal apps
    zip
    unzip

    (pkgs.writeShellScriptBin "nvidia-offload" ''
    exec env \
      __NV_PRIME_RENDER_OFFLOAD=1 \
      __GLX_VENDOR_LIBRARY_NAME=nvidia \
      __VK_LAYER_NV_optimus=NVIDIA_only \
      "$@"
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

  # ===== Intel + NVIDIA (Hybrid Offload di Wayland) =====
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;        # perlu untuk GNOME Wayland
    powerManagement.enable = true;    # hemat daya saat idle
    open = false;                     # proprietary (paling kompatibel untuk laptop)
    nvidiaSettings = true;

    prime = {
      offload.enable = true;          # Intel primary, NVIDIA untuk offload
      intelBusId  = "PCI:0:2:0";      # ubah jika lspci menunjukkan angka lain
      nvidiaBusId = "PCI:1:0:0";      # ubah jika lspci menunjukkan angka lain
    };
  };

  # Stack grafis & VA-API (Intel iGPU video decode)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;     # 32-bit libs (aman untuk kompatibilitas)
    extraPackages = with pkgs; [
      intel-media-driver     # VA-API untuk iGPU Intel
    ];
  };

  # Wayland environment variables
  environment.sessionVariables = {
    # Wayland general
    MOZ_ENABLE_WAYLAND = "1";        # Firefox
    NIXOS_OZONE_WL = "1";            # Chrome/Electron
    GDK_BACKEND = "wayland";         # GTK apps
    XDG_SESSION_TYPE = "wayland";    # Force Wayland session
    WLR_NO_HARDWARE_CURSORS = "1";   # Software cursor fallback
    
    # Qt Wayland
    QT_QPA_PLATFORM = "wayland";     # Force Wayland for Qt
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    
    # NVIDIA Wayland
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBGL_ALWAYS_SOFTWARE = "0";
    
    # Desktop environment
    XDG_CURRENT_DESKTOP = "Gnome";   
    XDG_SESSION_DESKTOP = "gnome";
    SDL_VIDEODRIVER = "wayland";
  };
  };

  # Pure Wayland configuration

  programs.nix-ld.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  services.upower.enable = true;
  services."power-profiles-daemon".enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "25.05";

  # XDG Portal Configuration
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
};
