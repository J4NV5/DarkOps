import ../. {} ({ config, ... }: {

  defaults = { name, ... }: {
    configuration = { lib, ... }: {
      networking.hostName = lib.mkDefault name;
    };

    nixpkgs = fetchTarball {
      url = "https://github.com/zkjanus/nixpkgs/tarball/44d823045803154544e5055d62e31f0a7be6b73d";
      sha256 = "1if3mcgxnkl79mcx13g8h5x7ys8bdxsrcb2kikzmbrp5y4i7b8v6";
    };
    # nixpkgs = fetchTarball {
    #   url = "https://github.com/NixOS/nixpkgs/tarball/fa0326ce5233f7d592271df52c9d0812bec47b84";
    #   sha256 = "1rzgjhzp5gnd49fl123cbd70zl4gmf7175150aj51h796mr7aah3";

    # };

  };

  # nodes.darkserver = { lib, config, ... }: {
  #   host = "root@dark.fi";
  #   successTimeout = 100;
  #   switchTimeout = 180;
  #   configuration = ./darkserver.nix;
  # };
  nodes.darkfi-services = { lib, config, ... }: {
    host = "root@185.165.171.77";
    successTimeout = 100;
    switchTimeout = 180;
    configuration = ./darkfi-services.nix;
  };


})
