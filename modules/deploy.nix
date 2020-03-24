{ lib, config, ... }:
let
  inherit (lib) types;

  nodeOptions = ({ name, pkgs, config, ... }:
    let
      switch = pkgs.runCommandNoCC "switch" {
        inherit (config) switchTimeout successTimeout ignoreFailingSystemdUnits;
      } ''
        mkdir -p $out/bin
        substituteAll ${../scripts/switch} $out/bin/switch
        chmod +x $out/bin/switch
      '';
      system = config.configuration.system.build.toplevel;
    in {
    options = {
      deployScripts = lib.mkOption {
        type = types.dagOf types.lines;
        default = {};
      };

      combinedDeployScript = lib.mkOption {
        type = types.package;
      };

      successTimeout = lib.mkOption {
        type = types.ints.unsigned;
        default = 20;
        description = ''
          How many seconds remote hosts should wait for the success
          confirmation before rolling back.
        '';
      };

      switchTimeout = lib.mkOption {
        type = types.ints.unsigned;
        default = 60;
        description = ''
          How many seconds remote hosts should wait for the system activation
          command to finish before considering it failed.
        '';
      };

      ignoreFailingSystemdUnits = lib.mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether a system activation should be considered successful despite
          failing systemd units.
        '';
      };

      # TODO: What about different ssh ports? Some access abstraction perhaps?
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        example = "root@172.18.67.46";
        description = ''
          How to reach the host via ssh. Deploying is disabled if null.
        '';
      };

      hasFastConnection = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether there is a fast connection to this host. If true it will cause
          all derivations to be copied directly from the deployment host. If
          false, the substituters are used when possible instead.
        '';
      };

      closurePaths = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = ''
          Derivation paths to copy to the host while deploying
        '';
      };

    };

    config.closurePaths = [ system switch ];

    config.deployScripts = {
      copy-closure = lib.dag.entryBefore ["switch"] ''
        echo "Copying closure to host..." >&2
        # TOOD: Prevent garbage collection until the end of the deploy
        tries=3
        while [ "$tries" -ne 0 ] &&
          ! NIX_SSH_OPTS="-o ServerAliveInterval=15" nix-copy-closure ${lib.optionalString (!config.hasFastConnection) "-s"} --to "$HOST" ${lib.escapeShellArgs config.closurePaths}; do
          tries=$(( $tries - 1 ))
          echo "Failed to copy closure, $tries tries left"
        done
      '';

      switch = lib.dag.entryAnywhere ''
        echo "Triggering system switcher..." >&2
        id=$(ssh -o BatchMode=yes "$HOST" "${switch}/bin/switch" start "${system}")

        echo "Trying to confirm success..." >&2
        prevstatus="unknown"
        prevactive=0
        active=1
        while [ "$active" != 0 ]; do
          # TODO: Because of the imperative network-setup script, when e.g. the
          # defaultGateway is removed, the previous entry is still persisted on
          # a rebuild switch, even though with a reboot it wouldn't. Maybe use
          # the more modern and declarative networkd to get around this
          set +e
          status=$(timeout --foreground 5 ssh -o ControlPath=none -o BatchMode=yes "$HOST" "${switch}/bin/switch" active "$id")
          active=$?
          set -e
          sleep 1
        done

        case "$status" in
          "success")
            echo "Successfully activated new system!" >&2
            ;;
          "failure")
            echo "Failed to activate new system! Rolled back to previous one" >&2
            echo "See /var/lib/system-switcher/system-$id/log for logs" >&2
            # TODO: Try to better show what failed
            ;;
          *)
            echo "This shouldn't occur!" >&2
            ;;
        esac
      '';
    };

    config.combinedDeployScript =
      let
        sortedScripts = (lib.dag.topoSort config.deployScripts).result or (throw "Cycle in DAG for deployScripts");
      in
      pkgs.writeScriptBin "deploy-${name}" (''
        #!${pkgs.runtimeShell}

        PATH=${lib.makeBinPath (with pkgs; [
          procps
          findutils
          gnused
          coreutils
          openssh
          nix
          rsync
          jq
        ])}

        set -euo pipefail

        # Kill all child processes when interrupting/exiting
        trap exit INT TERM
        trap 'ps -s $$ -o pid= | xargs -r -n1 kill' EXIT
        # Be sure to use --foreground for all timeouts, therwise a Ctrl-C won't stop them!
        # See https://unix.stackexchange.com/a/233685/214651

        # Prefix all output with host name
        # From https://unix.stackexchange.com/a/440439/214651
        exec > >(sed "s/^/[${name}] /")
        exec 2> >(sed "s/^/[${name}] /" >&2)
      '' + (if config.host == null then ''
        echo "Don't know how to reach node, you need to set a non-null value for nodes.\"$HOSTNAME\".host" >&2
        exit 1
      '' else ''
        HOST=${config.host}

        echo "Connecting to host..." >&2

        if ! OLDSYSTEM=$(timeout --foreground 5 \
            ssh -o ControlPath=none -o BatchMode=yes "$HOST" realpath /run/current-system\
          ); then
          echo "Unable to connect to host!" >&2
          exit 1
        fi

        if [ "$OLDSYSTEM" == "${system}" ]; then
          echo "No deploy necessary" >&2
          #exit 0
        fi

        ${lib.concatMapStringsSep "\n\n" ({ name, data }: ''
          # ======== PHASE: ${name} ========
          ${data}
        '') sortedScripts}

        echo "Finished" >&2
      ''));
    });

in {

  options = {
    defaults = lib.mkOption {
      type = lib.types.submodule nodeOptions;
    };

    deployScript = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
    };
  };

  # TODO: What about requiring either all nodes to succeed or all get rolled back?
  config.deployScript =
    let
      pkgs = import (import ../nixpkgs.nix) {
        config = {};
        overlays = [];
      };
      # TODO: Handle signals to kill the async command
    in pkgs.writeScript "deploy" ''
      #!${pkgs.runtimeShell}
      ${lib.concatMapStrings (node: lib.optionalString node.enabled ''

        ${node.combinedDeployScript}/bin/deploy-* &
      '') (lib.attrValues config.nodes)}
      wait
    '';

}