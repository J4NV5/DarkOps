import ../. {} ({ config, ... }: {

  defaults = { name, ... }: {
    configuration = { lib, ... }: {
      networking.hostName = lib.mkDefault name;
    };

    nixpkgs = fetchTarball {
      url = "https://github.com/zkjanus/nixpkgs/tarball/55572e9abb81743f5406988b45b70216c88ab0fb";
    sha256 = "16xcmggiybz33mpc9lxqvj98pgq0prdwly018j5cq0c13xz31a6g";
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
