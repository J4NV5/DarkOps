import ../. {} ({ config, ... }: {

  defaults = { name, ... }: {
    configuration = { lib, ... }: {
      networking.hostName = lib.mkDefault name;
    };

    nixpkgs = fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/tarball/856f48ece58767b67edf9bf8f899b1712f84e5e3";
      sha256 = "0sg2wm6hriwqy4bc2xdfy0ri7rmhb3p9m6zi7g8vg1rb146h6mv4";

    };

  };

  nodes.darkserver = { lib, config, ... }: {
    host = "root@dark.fi";
    successTimeout = 100;
    switchTimeout = 180;
    configuration = ./darkserver.nix;
  };

})
