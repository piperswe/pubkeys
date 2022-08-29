{
  inputs.nixpkgs.url = github:nixos/nixpkgs;
  inputs.flake-utils.url = github:numtide/flake-utils;

  description = "Piper's public cryptographic keys, usable from Nix flakes";

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      ssh = rec {
        raw = builtins.readFile ./ssh_public_keys;
        keys = builtins.split "\n" raw;
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
        });
      root = {
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
            users.user.${config.piperswe-pubkeys.user}.openssh.authorizedKeys.keys = ssh.keys;
          };
        };
      };
    in
    root // perSystem;
}
