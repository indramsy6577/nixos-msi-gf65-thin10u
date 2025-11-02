{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./termius.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Host & Network
  networking.hostName = "ctrlaltfocus";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

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

  # Desktop (GNOME Wayland only)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;
  programs.xwayland.enable = false;   # pure Wayland

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
    # jack.enable = true;  # kalau perlu
  };

  # Users
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

  # ACME (Let's Encrypt) - sesuaikan kalau tidak dipakai di laptop
  security.acme = {
    acceptTerms = true;
    defaults.email = "focus@ctrlaltfocus.web.id";
    certs."focus.ctrlaltfocus.web.id" = {
      dnsProvider = "cloudflare";
      credentialsFile = "/etc/secrets/cf.env";
      dnsPropagationCheck = true;
    };
  };

  # Browser
  programs.firefox.enable = true;

  # Unfree (Chrome, NVIDIA, VSCode, dsb)
  nixpkgs.config.allowUnfree = true;

  # OBS pakai ffmpeg-full (NVENC)
  nixpkgs.overlays = [
    (final: prev: {
      obs-studio = prev.obs-studio.override { ffmpeg = prev.ffmpeg-full; };
    })
  ];

  environment.systemPackages = with pkgs; [
    # umum
    curl git htop wget vim
    vscode-with-extensions
    google-chrome
    zip unzip

    # GNOME/Wayland tools
    qt6.qtwayland
    qt5.qtwayland
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    gnome-screenshot       # screenshot via GNOME (stabil di Wayland)

    # audio
    pavucontrol

    # container
    podman podman-compose podman-desktop

    # remote
    remmina
    winbox4

    # OBS + NVENC
    obs-studio
    ffmpeg-full

    # GPU testing
    pciutils            # lspci
    mesa-demos          # glxinfo/glxgears (via XWayland off; tapi tetap berguna)
    vulkan-tools        # vulkaninfo

    # helper: nvidia offload wrapper
    (pkgs.writeShellScriptBin "nvidia-offload" ''
      exec env \
        __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __VK_LAYER_NV_optimus=NVIDIA_only \
        "$@"
    '')

    # helper: jalankan OBS dengan NV libs terlihat & offload ke NVIDIA
    (pkgs.writeShellScriptBin "obs-nv" ''
      # Pastikan lib NVENC (libnvidia-encode.so) terlihat oleh OBS
      if [ -n "$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH"
      else
        export LD_LIBRARY_PATH="/run/opengl-driver/lib"
      fi
      exec nvidia-offload obs "$@"
    '')

    # Desktop entry untuk OBS (NVIDIA)
    (pkgs.makeDesktopItem {
      name = "obs-nv";
      desktopName = "OBS Studio (NVIDIA)";
      genericName = "Recording/Streaming";
      exec = "obs-nv";
      icon = "com.obsproject.Studio";
      comment = "OBS via NVIDIA offload (NVENC)";
      categories = [ "AudioVideo" "Recorder" ];
      terminal = false;
    })
  ];

  # Intel + NVIDIA (Hybrid Offload di Wayland)
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;       # wajib untuk Wayland GNOME
    powerManagement.enable = true;   # hemat daya
    open = false;                    # proprietary driver (lebih kompatibel)
    nvidiaSettings = true;

    prime = {
      offload.enable = true;         # Intel sebagai primary; NVIDIA buat offload
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Stack grafis baru (pengganti hardware.opengl*)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver     # VA-API untuk Intel iGPU (Comet Lake ok)
      nvidia-vaapi-driver    # NVDEC/VA-API bridge untuk NVIDIA (opsional)
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Env minimal untuk Wayland
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";   # Firefox
    NIXOS_OZONE_WL = "1";       # Chrome/Chromium/Electron/VSCode
    QT_QPA_PLATFORM = "wayland";
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";  # tak berpengaruh di pure Wayland, biarkan di wrapper saja
  };

  # XDG Portal (GNOME sudah cukup pakai portal GNOME)
  xdg.portal.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # Power/battery services
  services.upower.enable = true;
  services."power-profiles-daemon".enable = true;

  # nix-ld (untuk binary luar)
  programs.nix-ld.enable = true;

  system.stateVersion = "25.05";
}
