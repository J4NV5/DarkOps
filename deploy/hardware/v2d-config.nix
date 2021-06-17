{ lib, config, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "ehci_pci"
    "sr_mod"
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_blk"
    "virtio_scsi"
    "9p"
    "9pnet_virtio"
  ];
  boot.initrd.kernelModules = [
    "virtio_balloon" "virtio_console" "virtio_rng"
  ];
  boot.initrd.postDeviceCommands =
    ''
      # Set the system time from the hardware clock to work around a
      # bug in qemu-kvm > 1.5.2 (where the VM clock is initialised
      # to the *boot time* of the host).
      hwclock -s
    '';

  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  #security.rngd.enable = lib.mkDefault false;
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/67203570-b8e3-4a88-b24e-883aafb29826";
      fsType = "ext4";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/2f71be5e-5def-47aa-8813-56efe5f8bce1"; }
    ];

  nix.maxJobs = lib.mkDefault 6;

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda";

  networking = {
    enableIPv6 = true;
    # nat = {
    #   enable = true;
    #   externalInterface = "ens3";
    # };
    useDHCP = false;
    # usePredictableInterfaceNames = false;
    interfaces = {
      ens3 = {
        useDHCP = true;
        # ipv6 = {
        #   routes = [
        #     {
        #       address = "2a0b:ee80:0:2:185:189:151:64";
        #       prefixLength = 64;
        #       via = "2a0b:ee80:0:2::1";
        #     }
        #   ];
        # };
      };
    };
  };
}
