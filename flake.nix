{
  description = "Plant operator secrets on a device's FAT firmware partition and have NixOS copy them into root-only /run at boot. Reflash-safe: never bound to a rotating SSH host key.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Public read-only binary cache for this flake's build outputs (CI pushes here).
  nixConfig = {
    extra-substituters = [ "https://ismailkattakath.cachix.org" ];
    extra-trusted-public-keys = [
      "ismailkattakath.cachix.org-1:7BbEvLpASY7aNUZfpzRMWir1zjU3nqmllBTl8p7gr2I="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      darwinSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      allSystems = linuxSystems ++ darwinSystems;
      forAll = systems: f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      # The reusable NixOS module (system-agnostic).
      nixosModules.firmwareProvisioning = ./modules/firmware-provisioning.nix;
      nixosModules.default = self.nixosModules.firmwareProvisioning;

      # macOS companion: plant files onto the mounted FAT volume.
      packages = forAll darwinSystems (
        system: pkgs: {
          firmware-plant = pkgs.callPackage ./apps/firmware-plant.nix { };
          default = self.packages.${system}.firmware-plant;
        }
      );
      apps = forAll darwinSystems (
        system: _: {
          firmware-plant = {
            type = "app";
            program = "${self.packages.${system}.firmware-plant}/bin/firmware-plant";
          };
          default = self.apps.${system}.firmware-plant;
        }
      );

      # Eval check: the module produces the expected boot oneshot with the right
      # ordering + mount gate (builds a tiny derivation only if all assertions hold).
      checks = forAll linuxSystems (
        system: pkgs:
        let
          sys = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              ({ ... }: {
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "/dev/sda1";
                  fsType = "ext4";
                };
                system.stateVersion = "24.05";
                services.firmwareProvisioning = {
                  docsHint = "See RUNBOOK.md.";
                  files.demo-token = {
                    source = "demo-token";
                    target = "/run/demo-token";
                    required = true;
                    before = [ "demo.service" ];
                    requiredBy = [ "demo.service" ];
                  };
                };
              })
            ];
          };
          unit = sys.config.systemd.services."firmware-file-demo-token";
        in
        {
          module-evaluates = pkgs.runCommand "firmware-provisioning-eval" { } ''
            test "${unit.serviceConfig.Type}" = "oneshot"
            test "${unit.unitConfig.RequiresMountsFor}" = "/boot/firmware"
            test "${lib.elemAt unit.before 0}" = "demo.service"
            echo ok > "$out"
          '';
        }
      );

      formatter = forAll allSystems (_: pkgs: pkgs.nixfmt-rfc-style);
    };
}
