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

  # GNOME (Wayland)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Keyboard
  services.xserver.xkb = { layout = "us"; variant = ""; };

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
  };

  # User
  users.users.focus = {
    isNormalUser = true;
    description = "Control Alternative Focus";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    packages = with pkgs; [ 
      tree
    ];
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

  programs.direnv.enable = true;
  programs.firefox.enable = true;
  programs.starship.enable = true;

  # Jalankan ~/.bashrc otomatis di semua shell login
  environment.shellInit = ''
    if [ -f ~/.bashrc ]; then
      source ~/.bashrc
    fi
  '';

  nixpkgs.config.allowUnfree = true;

  # OBS pakai ffmpeg-full (NVENC)
  nixpkgs.overlays = [
    (final: prev: {
      obs-studio = prev.obs-studio.override { ffmpeg = prev.ffmpeg-full; };
    })
  ];

  fonts.fontDir.enable = true;
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    brave curl flameshot
    (pkgs.writeShellScriptBin "flameshot-wayland" ''
      #!/bin/sh
      env XDG_CURRENT_DESKTOP=GNOME QT_QPA_PLATFORM=wayland flameshot "$@"
    '')

    satty

    qt6.qtwayland qt5.qtwayland
    alacritty direnv docker docker-compose jetbrains-mono neofetch nerd-fonts.jetbrains-mono git google-chrome htop neovim nix-ld obs-studio ffmpeg-full
    pavucontrol remmina starship tmux vim vscode wget winbox4
    pciutils mesa-demos vivaldi vulkan-tools
    zip unzip


    # OBS NVENC launcher (tetap boleh)
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

    # Termius
    (pkgs.callPackage ./termius.nix { })
    
    # Chrome (NVIDIA) launcher khusus
    (pkgs.writeShellScriptBin "chrome-nv" ''
      exec nvidia-offload google-chrome-stable \
        --use-gl=desktop \
        --enable-features=UseOzonePlatform,Vulkan,CanvasOopRasterization \
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

  # ===== Intel default + NVIDIA offload (hemat baterai) =====
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;   # aktifkan runtime PM (dGPU bisa sleep)
    open = false;
    nvidiaSettings = true;

    prime = {
      offload = {
        enable = true;               # Intel = default
        enableOffloadCmd = true;     # sediakan wrapper 'nvidia-offload'
      };
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Grafik + VA-API
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      nvidia-vaapi-driver
    ];
  };

  # Wayland env (aman untuk default Intel; hindari variabel yang memaksa NVIDIA)
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "GNOME";
    XDG_SESSION_DESKTOP = "gnome";
    SDL_VIDEODRIVER = "wayland";
    # ⚠️ JANGAN set __GLX_VENDOR_LIBRARY_NAME atau __NV_* secara global di sini
  };

  programs.nix-ld.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  services.upower.enable = true;
  services."power-profiles-daemon".enable = true;

  networking.firewall.enable = false;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.common.default = "*";

  system.stateVersion = "25.05";
}
