import ../. {} ({ config, ... }: {

  defaults = { name, ... }: {
    configuration = { lib, ... }: {
      networking.hostName = lib.mkDefault name;
    };

    # Which nixpkgs version we want to use for this node
    nixpkgs = fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/tarball/721312288f7001215a0d482579cd013dec397d16";
      sha256 = "0gfibirsmggm3f4sjq73p091ynayk2r64afks99l0nslbapwnlf8";

    };
  };

  nodes.darkserver = { lib, config, ... }: {
    host = "root@dark.fi";
    successTimeout = 100;
    switchTimeout = 180;
    configuration = ./darkserver.nix;
  };

})
