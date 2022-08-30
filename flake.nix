{
  inputs.nixpkgs.url = github:nixos/nixpkgs;
  inputs.flake-utils.url = github:numtide/flake-utils;

  description = "Piper's public cryptographic keys, usable from Nix flakes";

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      ssh = rec {
        raw = builtins.readFile ./ssh_public_keys;
        keys = builtins.filter (x: (builtins.isString x) && x != "") (builtins.split "\n" raw);
      };
      pgp = rec {
        raw = builtins.readFile ./pgp_public_keys;
      };
      perSystem = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          packages.sshAuthorizedKeys = pkgs.writeText "authorized_keys" ssh.raw;

          devShells.fetch = pkgs.mkShell {
            buildInputs = [
              pkgs.wget
            ];
          };
          devShells.default = devShells.fetch;

          checks = {
            sshAuthorizedKeys = packages.sshAuthorizedKeys;
            sshRawJSON = pkgs.writeText "ssh-raw.json" (builtins.toJSON ssh.raw);
            sshKeysJSON = pkgs.writeText "ssh-keys.json" (builtins.toJSON ssh.keys);
            pgpRawJSON = pkgs.writeText "pgp-raw.json" (builtins.toJSON pgp.raw);
          };
        });
      root = rec {
        lib = {
          inherit ssh pgp;
        };

        nixosModules.sshAuthorizedKeys = { config, lib, ... }: {
          options.piperswe-pubkeys = {
            enable = lib.mkEnableOption "SSH public keys for Piper";
            user = lib.mkOption {
              type = lib.types.str;
              default = "pmc";
            };
          };
          config = lib.mkIf config.piperswe-pubkeys.enable {
            users.users.${config.piperswe-pubkeys.user}.openssh.authorizedKeys.keys = ssh.keys;
          };
        };

        checks = perSystem.checks // {
          x86_64-linux = perSystem.checks.x86_64-linux // {
            system =
              let
                module = { modulesPath, ... }: {
                  imports = [
                    "${modulesPath}/installer/cd-dvd/iso-image.nix"
                  ];
                  users.users.pmc = {
                    isNormalUser = true;
                    description = "Piper McCorkle";
                  };
                  piperswe-pubkeys = {
                    enable = true;
                    user = "pmc";
                  };
                  system.stateVersion = "22.05";
                };
                system = nixpkgs.lib.nixosSystem {
                  system = "x86_64-linux";
                  modules = [ nixosModules.sshAuthorizedKeys module ];
                };
              in
              system.config.system.build.toplevel;
          };
        };
      };
    in
    perSystem // root;
}
