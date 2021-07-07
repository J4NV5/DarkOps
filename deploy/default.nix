import ../. {} ({ config, ... }: {

  defaults = { name, ... }: {
    configuration = { lib, ... }: {
      networking.hostName = lib.mkDefault name;
    };

    nixpkgs = fetchTarball {
      url = "https://github.com/zkjanus/nixpkgs/tarball/024035e0fbd00f5dd499ee6c5830d469b9604037";
    sha256 = "0vi3ql5ivkrwjq3di54lihk2r1g0jix5wyi5902zxbhpnvsr4iy9";
    };
    # nixpkgs = fetchTarball {
    #   url = "https://github.com/NixOS/nixpkgs/tarball/fa0326ce5233f7d592271df52c9d0812bec47b84";
    #   sha256 = "1rzgjhzp5gnd49fl123cbd70zl4gmf7175150aj51h796mr7aah3";

    # };

  };

  nodes.darkserver = { lib, config, ... }: {
    host = "root@dark.fi";
    successTimeout = 100;
    switchTimeout = 180;
    configuration = ./darkserver.nix;
  };

})
