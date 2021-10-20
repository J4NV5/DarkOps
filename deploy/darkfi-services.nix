{ lib, config, pkgs, ... }:
{

  imports = [
    ./hardware/floki.nix
    ./cachix.nix
  ];

  networking = {
    hostName = "darkfi-services";
    domain = "dark.fi";
    firewall.allowPing = true;
    useDHCP = false;
    # usePredictableInterfaceNames = false;
	  defaultGateway = "185.165.171.1";
	  nameservers = [ "1.1.1.1" "9.9.9.9" ];
    firewall = {
      enable = true;
      interfaces.ens18 =
        {
          allowedUDPPorts = [

          ];
          allowedTCPPorts = [
            3333 4444 8000 9000 80
          ];
        };
    };
    interfaces = {
      ens18 = {
        useDHCP = false;
	      ipv4 = {
	        addresses = [
	          {
		          address = "185.165.171.77";
		          prefixLength = 24;
 		        }
	        ];
        };
      };
    };
  };
  boot.cleanTmpDir = true;

  time.timeZone = "Europe/Amsterdam";

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };
  nixpkgs.overlays = [
    (self: super: { nix-direnv = super.nix-direnv.override { enableFlakes = true; }; } )
  ];
  services = {
    openssh = {
      enable = true;
      permitRootLogin = "prohibit-password";
      #authorizedKeysCommand = "${pkgs.cmatrix} \"%u\" \"%h\" \"%t\" \"%k\"";
      authorizedKeysCommandUser = "root";
    };
    emacs = {
      enable = true;
      defaultEditor = true;
      package = pkgs.emacs-nox;
    };

    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "testnet.gateway-protocol.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
        };
        "testnet.gateway-publish.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
        };
        "testnet.cashier.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
        };
        "185.165.171.77" = {
          enableACME = false;
          forceSSL = false;
          root = "/var/www/darkfi/";
          locations."/".proxyPass = lib.mkForce null;
        };


      }; # virtualhosts
    };

    redis = {
      enable = true;
    };

    borgbackup = {
      # jobs.home-danbst = {
      #   paths = "${taskserverDataDir}";
      #   encryption.mode = "none";
      #   environment.BORG_RSH = "ssh -i /home//.ssh/id_ed25519";
      #   repo = "ssh://user@example.com:23/path/to/backups-dir/home-danbst";
      #   compression = "auto,zstd";
      #   startAt = "daily";
      # };
    };
  };
  security = {
    acme = {
      acceptTerms = true;
      email = "janus@dark.fi";
    };
  };

  environment = {
    systemPackages = with pkgs; [
      gnutls
      inetutils
      mtr
      ranger
      sysstat
      libressl
      lsof
      nmap
      git

      jq
      screen

      python
      python38Packages.virtualenv

      tcpdump

      direnv
      nix-direnv
    ];
    variables = {
      TERM = "xterm-color";
    };
    pathsToLink = [
      "/share/nix-direnv"
    ];
  };

  sound.enable = false;

  users = {
    motd = "
▀█████████████████████████████████▀
  ███████████████████████████████▀
   ████████████▀▀▀▀▀▀███████████
    ▀███████▀  ▄▄██▄  ▀████████
     ▀████▀   ██▀ ▀██   ▀█████
      ▀███▄   ██   ██   ▄███▀
        ████▄  ▀███▀   ▄███▀
         █████▄▄   ▄▄█████▀
          ███████████████▀
           █████████████
            ▀██████████
             ▀████████
              ▀█████▀
                ███▀
                 █▀

Welcome to Darkfi-services. Let there be dark.

";
    users = {
      janus = {
        isNormalUser = true;
        home = "/home/janus";
        description = "Janus";
        extraGroups = [ "wheel" "networkmanager" ];
        openssh.authorizedKeys.keyFiles = [ ./secrets/pubkeys/janus ];
      };
      root = {
        openssh.authorizedKeys.keys =
          import ./secrets/pubkeys/tasks.nix { inherit pkgs; };
        openssh.authorizedKeys.keyFiles = [
          ./secrets/pubkeys/parazyd
          ./secrets/pubkeys/pythia
          ./secrets/pubkeys/root
          ./secrets/pubkeys/xesan
        ];
      };
    };
  };

  system.stateVersion = "21.05";

}
