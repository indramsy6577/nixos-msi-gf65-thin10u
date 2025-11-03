{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  networking.hostName = "ctrlaltfocus";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Jakarta";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = { LC_ALL = "en_US.UTF-8"; };

  # === GNOME + Wayland ===
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.xkb.layout = "us";

  # === Audio (PipeWire) ===
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # === User ===
  users.users.focus = {
    isNormalUser = true;
    description = "Control Alternative Focus";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ tree ];
  };

  security.sudo.extraRules = [{
    users = [ "focus" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # === ACME (Cloudflare) ===
  security.acme = {
    acceptTerms = true;
    defaults.email = "focus@ctrlaltfocus.web.id";
    certs."focus.ctrlaltfocus.web.id" = {
      dnsProvider = "cloudflare";
      credentialsFile = "/etc/secrets/cf.env";
      dnsPropagationCheck = true;
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      obs-studio = prev.obs-studio.override { ffmpeg = prev.ffmpeg-full; };
    })
  ];

  fonts.fontDir.enable = true;
  programs.starship.enable = true;

  environment.shellInit = ''
    if [ -f ~/.bashrc ]; then
      source ~/.bashrc
    fi
  '';

  # === NVIDIA PRIME Offload ===
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # === GPU + VAAPI ===
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      nvidia-vaapi-driver
    ];
  };

  # === Wayland Variables ===
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "GNOME";
    SDL_VIDEODRIVER = "wayland";
  };

  # === System Packages (GNOME multimedia) ===
  environment.systemPackages = with pkgs; [
    # Core tools
    alacritty curl git htop neovim starship tmux vim wget zip unzip

    # Browsers
    brave google-chrome vivaldi widevine-cdm

    # Media players
    vlc mpv celluloid  # celluloid = GTK frontend for mpv

    # Audio tools
    audacity easyeffects pavucontrol

    # Video editing (non-KDE)
    shotcut handbrake obs-studio ffmpeg-full

    # Image editing
    gimp inkscape krita blender imagemagick

    # Codec / GStreamer
    gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good 
    gst_all_1.gst-plugins-bad gst_all_1.gst-plugins-ugly gst_all_1.gst-vaapi lame 
    x264 x265 libopus flac a52dec faad2

    # Utils
    flameshot satty remmina winbox4 podman podman-compose podman-desktop
    pciutils mesa-demos vulkan-tools

    # Termius
    (pkgs.callPackage ./termius.nix { })

    # OBS NVIDIA launcher
    (pkgs.writeShellScriptBin "obs-nv" ''
      export LIBVA_DRIVER_NAME=nvidia
      export NVD_BACKEND=direct
      export GDK_BACKEND=wayland
      export QT_QPA_PLATFORM=wayland
      export XDG_SESSION_TYPE=wayland
      export OBS_USE_EGL=1
      nvidia-offload obs "$@"
    '')
    (makeDesktopItem {
      name = "obs-nv";
      desktopName = "OBS Studio (NVIDIA)";
      exec = "obs-nv";
      icon = "com.obsproject.Studio";
      categories = [ "AudioVideo" "Recorder" ];
      terminal = false;
    })

    # Chrome NVIDIA launcher
    (pkgs.writeShellScriptBin "chrome-nv" ''
      exec nvidia-offload google-chrome-stable \
        --use-gl=desktop \
        --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,UseOzonePlatform,Vulkan,CanvasOopRasterization \
        --ozone-platform=wayland \
        --ignore-gpu-blocklist "$@"
    '')
    (makeDesktopItem {
      name = "chrome-nv";
      desktopName = "Google Chrome (NVIDIA)";
      exec = "chrome-nv";
      icon = "google-chrome";
      categories = [ "Network" "WebBrowser" ];
      terminal = false;
    })
  ];

  # === Services ===
  services.printing.enable = true;
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  services.upower.enable = true;
  services."power-profiles-daemon".enable = true;
  networking.firewall.enable = false;

  # === XDG Portals ===
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.common.default = "*";

  programs.firefox.enable = true;
  programs.nix-ld.enable = true;

  system.stateVersion = "25.05";
}
