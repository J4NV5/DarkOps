{ lib, config, pkgs, ... }:
let
  shcfg = config.services.sourcehut;
  srht-modules = "/home/janus/src/darkfi/nixpkgs";
  # WIP PR
  #srht-modules = fetchTarball "https://git.dark.fi/~janus/nixpkgs/archive/b58438e69247770444c35e354ef9f99691c48748.tar.gz";
  pkgs-srht = import (srht-modules) {};

in
{

  imports = [
    ./hardware/v2d-config.nix
    # Import only the sourcehut modules
    "${srht-modules}/nixos/modules/services/misc/sourcehut"
  ];

  networking = {
    hostName = "darkserver";
    domain = "dark.fi";
    firewall = {
      enable = true;
      interfaces.ens3 = let
        range = with config.services.coturn; [ {
          from = min-port;
          to = max-port;
        } ];
      in
        {
          allowedUDPPortRanges = range;
          allowedUDPPorts = [
            5349 5350 51820 1025 1143 8080
          ];
          allowedTCPPortRanges = range;
          allowedTCPPorts = [
            80 443 1025 3478 3479 8008 53589
            5007 5001 5002 5003 5004 5005 5006 5011 5014
            5107 5101 5102 5103 5104 5105 5106 5111 5114
            9418
          ];
        };
    };
    # nat = {
    #   enable = true;
    #   externalInterface = "ens3";
    #   forwardPorts = [
    #     {
    #       destination = "127.0.0.1:8008";
    #       proto = "tcp";
    #       sourcePort = 8008;
    #       loopbackIPs = [ "127.0.0.1" ];
    #     }
    #   ];
    # };
  };

  time.timeZone = "Europe/Amsterdam";

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.overlays = [
    (self: super: {
      element-web = super.element-web.override {
        conf = {
          default_server_config = {
            "m.homeserver" = {
              "base_url" = "https://matrix.${config.networking.domain}";
              "server_name" = "${config.networking.domain}";
            };
            "m.identity_server" = {
              "base_url" = "https://vector.im";
            };
          };

          jitsi.preferredDomain = "jitsi.${config.networking.domain}";
        };
      };
      sourcehut = pkgs-srht.sourcehut;
    }
    )
  ];

  services = {
    sourcehut = {
      enable = true;
      services = [
        "meta"
        "todo"
        "git"
        "hub"
        "builds"
        "lists"
        "man"
        "paste"
        "dispatch"
      ];
      originBase = "${config.networking.domain}";
      meta = {
        port = 5007;
      };
      builds.enableWorker = true;
      builds.images =
        let
          # Pinning to unstable to allow usage with flakes and limit rebuilds.
          pkgs_unstable = builtins.fetchGit {
            url = "https://github.com/NixOS/nixpkgs";
            rev = "ff96a0fa5635770390b184ae74debea75c3fd534";
            ref = "nixos-unstable";
          };
          image_from_nixpkgs = pkgs_unstable: (import ("${pkgs.sourcehut.buildsrht}/lib/images/nixos/image.nix") {
            pkgs = (import pkgs_unstable { });
          });
        in
          {
            nixos.unstable.x86_64 = image_from_nixpkgs pkgs_unstable;
          };
      settings."sr.ht" = {
        environment = "production";
        site-name = "DarkForge";
        site-blurb = "forge of the Dark Renaissance";
        owner-name = "Janus";
        owner-email = "janus@dark.fi";
        global-domain = "${config.networking.domain}";
        origin = "https://${config.networking.domain}";
        secret-key= "${builtins.readFile ./secrets/sourcehut/secret_key}";
        network-key = "${builtins.readFile ./secrets/sourcehut/network_key}";
        service-key = "${builtins.readFile ./secrets/sourcehut/service_key}";
        private-key= "${builtins.readFile ./secrets/sourcehut/private_key}";
      };
      settings."dispatch.sr.ht" = {
        origin = "https://dispatch.${config.networking.domain}";
      };
      settings."git.sr.ht" = {
        origin = "https://git.${config.networking.domain}";
        outgoing-domain = "https://git.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/git_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/git_client_secret}";
        repos = "/var/lib/git";
      };
      settings."hub.sr.ht" = {
        origin = "https://code.${config.networking.domain}";
      };
      settings."builds.sr.ht" = {
        origin = "https://builds.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/builds_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/builds_client_secret}";
      };
      settings."builds.sr.ht::worker".name = "localhost:12345";
      settings."lists.sr.ht" = {
        origin = "https://lists.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/lists_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/lists_client_secret}";
      };
      settings."man.sr.ht" = {
        origin = "https://man.${config.networking.domain}";
      };
      settings."paste.sr.ht" = {
        origin = "https://paste.${config.networking.domain}";
      };
      settings."todo.sr.ht" = {
        origin = "https://todo.${config.networking.domain}";
      };
      settings."meta.sr.ht::settings".registration = "no";
      settings."meta.sr.ht::settings".onboarding-redirect =
        shcfg.settings."meta.sr.ht".origin;
      settings."meta.sr.ht" = {
        origin = "https://meta.${config.networking.domain}";
      };
      settings.webhooks = {
        origin = "https://${config.networking.domain}";
        private-key =
          "${builtins.readFile ./secrets/sourcehut/webhooks_private_key}";
      };
      settings.mail = {
        smtp-host = "localhost";
        smtp-port = 1025;
        smtp-user = "org@dark.fi";
        smtp-from = "org@dark.fi";
        smtp-password = "${builtins.readFile ./secrets/smtp_pass}";
      };
    };
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
    solr.enable = true;
    taskserver = {
      enable = true;
      fqdn = "tasks.dark.fi";
      debug = false;
      listenHost = "::";
      listenPort = 53589;
      dataDir = "/data";
      organisations = {
        DarkFi = {
          groups = [ "staff" "outsiders" ];
          users = [ "janus" "plato" "narodnik" "xesan" "rose" ];
        };
      };
    };

    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "matrix.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://localhost:8008";
            # extraConfig = ''
            #   return 404;
            # '';
          };
          locations."/_matrix" = {
            proxyPass = "http://localhost:8008";
          };
        };
        "element.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            root = pkgs.element-web;
          };
        };

        "bot.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
        };

        ${config.services.jitsi-meet.hostName} = {
          enableACME = true;
          forceSSL = true;
        };
        "${config.networking.domain}" = {
          enableACME = true;
          forceSSL = true;
          root = "/var/www/dark.fi/build";

          locations."= /.well-known/matrix/server".extraConfig =
            let
              server = {
                "m.server" = "matrix.${config.networking.domain}:443";
              };
            in ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON server}';
          '';
          locations."= /.well-known/matrix/client".extraConfig =
            let
              client = {
                "m.homeserver" =  {
                  "base_url" = "https://matrix.${config.networking.domain}";
                };
                "m.identity_server" =  {
                  "base_url" = "https://vector.im";
                };
              };
            in ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON client}';
          '';
          locations."= /services" = {
            proxyPass = "http://localhost:4050";
          };
        };
        "builds.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5002";
          locations."/query".proxyPass = "http://127.0.0.1:5102";
          locations."/static".root = "${pkgs-srht.sourcehut.buildsrht}/${pkgs-srht.sourcehut.python.sitePackages}/buildsrht";
        };
        "dispatch.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5005";
          locations."/query".proxyPass = "http://127.0.0.1:5105";
          locations."/static".root = "${pkgs-srht.sourcehut.dispatchsrht}/${pkgs.sourcehut.python.sitePackages}/dispatchsrht";
        };
        "git.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5001";
          locations."/query".proxyPass = "http://127.0.0.1:5101";
          locations."/static".root = "${pkgs-srht.sourcehut.gitsrht}/${pkgs-srht.sourcehut.python.sitePackages}/gitsrht";
        };
        "lists.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5006";
          locations."/query".proxyPass = "http://127.0.0.1:5106";
          locations."/static".root = "${pkgs-srht.sourcehut.listssrht}/${pkgs-srht.sourcehut.python.sitePackages}/listssrht";
        };
        "man.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5004";
          locations."/query".proxyPass = "http://127.0.0.1:5104";
          locations."/static".root = "${pkgs-srht.sourcehut.mansrht}/${pkgs-srht.sourcehut.python.sitePackages}/mansrht";
        };
        "meta.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5007";
          locations."/query".proxyPass = "http://127.0.0.1:5107";
          locations."/static".root = "${pkgs-srht.sourcehut.metasrht}/${pkgs-srht.sourcehut.python.sitePackages}/metasrht";
        };
        "code.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5014";
          locations."/query".proxyPass = "http://127.0.0.1:5114";
          locations."/static".root = "${pkgs-srht.sourcehut.hubsrht}/${pkgs-srht.sourcehut.python.sitePackages}/hubsrht";

        };
        "paste.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5011";
          locations."/query".proxyPass = "http://127.0.0.1:5111";
          locations."/static".root = "${pkgs-srht.sourcehut.pastesrht}/${pkgs-srht.sourcehut.python.sitePackages}/pastesrht";
        };
        "todo.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5003";
          locations."/query".proxyPass = "http://127.0.0.1:5103";
          locations."/static".root = "${pkgs-srht.sourcehut.todosrht}/${pkgs-srht.sourcehut.python.sitePackages}/todosrht";
        };
      }; # virtualhosts
    };

    matrix-synapse = with config.services.coturn; {
      enable = true;
      server_name = "${config.networking.domain}";
      enable_metrics = true;
      enable_registration = false;
      federation_rc_concurrent = "0";
      federation_rc_reject_limit = "0";
      registration_shared_secret =
        "${builtins.readFile ./secrets/matrix_registration}";
      verbose = "0";
      database_type = "psycopg2";
      database_args = {
        password = "synapse";
      };
      listeners = [
        {
          port = 8008;
          bind_address = "";
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              compress = true; #in place of load balancer
              names = ["client" "webclient" "federation"];
            }
          ];
        }
      ];
      turn_uris = [
        "turn:${realm}:3478?transport=udp"
        "turn:${realm}:3478?transport=tcp"
      ];
      turn_shared_secret = static-auth-secret;
      turn_user_lifetime = "1h";
      public_baseurl = "https://matrix.dark.fi/";
      extraConfig = ''
        encryption_enabled_by_default_for_room_type: all
        email:
          smtp_host: localhost
          smtp_port: 1025
          smtp_user: "org@dark.fi"
          smtp_pass: "${builtins.readFile ./secrets/smtp_pass}"
          notif_from: "%(app)s Matrix server <org@dark.fi>"
          app_name: darkfi
          client_base_url: "https://element.${config.networking.domain}"
      '';
    };
    go-neb = {
      enable = true;
      baseUrl = "https://bot.${config.networking.domain}";
      config = {
        clients = [{
          UserID = "@b1-66er:dark.fi";
          AccessToken =
            "${builtins.readFile ./secrets/matrix_bot_access_token}";
          HomeserverURL = "http://localhost:8008";
          Sync = true;
          AutoJoinRooms = true;
          DisplayName = "B1-66ER";
          #AcceptVerificationFromUsers = [":localhost:8008"];
        }];
        realms = [
          {
            ID = "github_realm";
            Type =  "github";
            Config = {};
          }
        ];
        sessions = [
          {
            SessionID = "github_session";
            RealmID = "github_realm";
            UserID = "@b1-66er:dark.fi";
            Config = {
              AccessToken =
                "${builtins.readFile ./secrets/github_session_token}";
              Scopes = "admin:org_hook,admin:repo_hook,repo,user";
            };
          }
        ];
        services = [
          {
            ID = "echo_service";
            Type = "echo";
            UserID = "@b1-66er:dark.fi";
            Config = {};
          }
          {
            ID = "github_webhook_service";
            Type = "github-webhook";
            UserID = "@b1-66er:dark.fi";
            Config = {
              RealmID = "github_realm";
              ClientUserID = "@b1-66er:dark.fi";
              Rooms = {
                "!MODZOZydPqCRdulXmR:dark.fi" = {
                  Repos = {
                    "zkjanus/matrix-action" = {
                        Events = ["push" "issues"];
                      };
                  };
                };
              };
            };
          }

          {
            ID = "github_cmd_service";
            Type = "github";
            UserID = "@b1-66er:dark.fi"; # requires a Syncing client
            Config = {
              RealmID = "github_realm";
            };
          }
        ];
      };
    };
    postgresql = {
      enable = true;
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
            TEMPLATE template0
            LC_COLLATE = "C"
            LC_CTYPE = "C";
        '';
    };
    jitsi-meet = {
      enable = true;
      hostName = "jitsi.${config.networking.domain}";
      videobridge.enable = true;
    };
    jitsi-videobridge = {
      enable = true;
      openFirewall = true;
    };
    coturn = rec {
      enable = true;
      use-auth-secret = true;
      static-auth-secret = "${builtins.readFile ./secrets/coturn}";
      realm = "turn.${config.networking.domain}";
      no-tcp-relay = true;
      no-tls = true;
      no-dtls = true;
      no-cli = true;
      min-port = 49000;
      max-port = 50000;
      # cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
      # pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";

      extraConfig = ''
        user-quota=12
        total-quota=1200
        # for debugging
        verbose
        # ban private IP ranges
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.88.99.0-192.88.99.255
        denied-peer-ip=244.0.0.0-224.255.255.255
        denied-peer-ip=255.255.255.255-255.255.255.255
        allowed-peer-ip=192.168.191.127
    '';
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
      cmatrix
      gnutls
      inetutils
      mtr
      ranger
      sysstat
      element-web
      docker-compose
      matrix-synapse
      taskwarrior
      libressl
      lsof
      nmap
      git

      jq
      screen
      hydroxide

      python
      python38Packages.virtualenv

      tcpdump
    ];
    variables = {
      TERM = "xterm-color";
    };

  };
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  sound.enable = false;

  users = {
    motd = "
  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
   ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
    ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
     ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
       :::::::::::::::::::::::::''''::::::::::::::::::::::::::
        ::::::::::::::::::::'    ...    '::::::::::::::::::::
         ::::::::::::::::'   .:::::::::.   '::::::::::::::::
          :::::::::::::'    :::::::::::::    '::::::::::::'
           ':::::::::'     :::::'   ':::::     ':::::::::'
            ':::::::.      :::::     :::::      .:::::::'
             '::::::::     :::::.   .:::::     ::::::::'
               ::::::::.    :::::::::::::    .::::::::
                :::::::::.   ':::::::::'    .::::::::'
                 :::::::::::.           .:::::::::::
                  ':::::::::::::::::::::::::::::::'
                   ':::::::::::::::::::::::::::::'
                    ':::::::::::::::::::::::::::'
                      :::::::::::::::::::::::::
                       :::::::::::::::::::::::
                        :::::::::::::::::::::
                         ::::::::::::::::::'
                          ':::::::::::::::'
                           ':::::::::::::'
                            ':::::::::::'
                              :::::::::
                               :::::::
                                :::::
                                 ':'
              Welcome to Darkserver. Let there be dark.

";
    users = {
      git = {
        home = "/var/lib/git";
        isNormalUser = true;
      };
      tasks = {
        home = "/home/tasks";
        isNormalUser = true;
        description = "Taskwarrior Account";
        extraGroups = [ "taskd" ];
        openssh.authorizedKeys.keys =
          import ./secrets/pubkeys/tasks.nix { inherit pkgs; };
      };
      janus = {
        isNormalUser = true;
        home = "/home/janus";
        description = "Janus";
        extraGroups = [ "wheel" "networkmanager" "taskd" ];
        openssh.authorizedKeys.keyFiles = [ ./secrets/pubkeys/janus ];
      };
      root = {
        openssh.authorizedKeys.keyFiles = [ ./secrets/pubkeys/root ];
      };
    };
  };

  system.stateVersion = "20.09";

}
