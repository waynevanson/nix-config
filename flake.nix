# We should stay on stable nixos-versions, so we don't break our server between updates.
# How to use separate for profiles?
{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-26.05";
    };
    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    nixpkgs-forgejo-runner = {
      url = "github:nixos/nixpkgs/ebbed83ea980369df17fef7c6820c8f5d26fc1e5";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      # todo: 26.05 doesn't contain pi agent.
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      disko,
      fenix,
      home-manager,
      nixos-anywhere,
      nixpkgs-unstable,
      nixpkgs,
      self,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      rustToolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-gh/xTkxKHL4eiRXzWv8KP7vfjSk61Iq48x47BEDFgfk=";
      };
      createNixosConfigurations = nixpkgs.lib.mapAttrs (
        _hostname: hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              nixpkgs.config.allowUnfree = true;
            }
            disko.nixosModules.default
            sops-nix.nixosModules.sops
            hostModule
          ];
          specialArgs = {
            inherit inputs system self;
          };
        }
      );
      createAppScripts = pkgs.lib.mapAttrs (
        scriptName: scriptBody: {
          type = "app";
          program = "${pkgs.writeShellScriptBin scriptName scriptBody}/bin/${scriptName}";
        }
      );
      createHomeConfigurations = pkgs.lib.mapAttrs (
        username: profileModule:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs-unstable { inherit system; };
          extraSpecialArgs = {
            inherit system;
            inputs = inputs // {
              nixpkgs = nixpkgs-unstable;
            };
          };
          modules = [
            {
              home = {
                username = username;
                homeDirectory = "/home/${username}";
                stateVersion = "25.05";
                enableNixpkgsReleaseCheck = false;
              };
            }
            profileModule
          ];
        }
      );
      createPackages = pkgs.lib.mapAttrs (packageName: modulePath: pkgs.callPackage modulePath { });
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          biome
          nixos-anywhere.packages.${system}.default
          disko.packages.${system}.default
          rustToolchain
          sops
          ssh-to-age
          yq
        ];
      };
      apps.${system} = createAppScripts {
        server = ''
          nixos-rebuild \
          $1 \
          --flake .#server \
          --target-host 192.168.68.55 \
          --sudo
        '';
        "server-overwrite" = ''
          set -euo pipefail

          if [[ $# -lt 1 ]]; then
            echo "usage: nix run .#server-overwrite -- root@<TARGET_IP> [ssh_identity_file]" >&2
            exit 1
          fi

          target_host="$1"
          if [[ "$target_host" != *@* ]]; then
            target_host="root@$target_host"
          fi
          identity_file="''${2:-$HOME/.ssh/id_ed25519}"

          repo_root=$(git rev-parse --show-toplevel)
          cd "$repo_root"

          # Keep the generated host key local and out of git. If it already
          # exists we reuse it so sops secrets survive reinstalls.
          key_dir="$repo_root/.secrets/server"
          host_key="$key_dir/ssh_host_ed25519_key"
          host_pub="$host_key.pub"

          umask 077
          mkdir -p "$key_dir"
          chmod 700 "$key_dir"

          if [[ ! -f "$host_key" ]]; then
            echo "Generating a new server SSH host key at $host_key"
            ${pkgs.openssh}/bin/ssh-keygen \
              -q \
              -t ed25519 \
              -N "" \
              -C "root@server" \
              -f "$host_key"
          else
            echo "Reusing existing server SSH host key at $host_key"
          fi

          # Always derive the public key from the private key so they cannot
          # drift apart.
          ${pkgs.openssh}/bin/ssh-keygen -y -f "$host_key" > "$host_pub"
          chmod 600 "$host_key"
          chmod 644 "$host_pub"

          age_recipient=$(${pkgs.ssh-to-age}/bin/ssh-to-age -i "$host_pub")
          echo "Server age recipient: $age_recipient"

          # Point the server's sops recipient at the key we just generated.
          if ! grep -q '&server_homelab_ssh' .sops.yaml; then
            echo "error: .sops.yaml does not define the &server_homelab_ssh anchor" >&2
            exit 1
          fi

          sed -i -E \
            "s|(&server_homelab_ssh[[:space:]]+)age1[a-z0-9]+|\1$age_recipient|" \
            .sops.yaml

          if ! grep -q "&server_homelab_ssh $age_recipient" .sops.yaml; then
            echo "error: failed to update the server recipient in .sops.yaml" >&2
            exit 1
          fi

          # Re-encrypt the secrets so the server host key can decrypt them.
          ${pkgs.sops}/bin/sops updatekeys --yes .sops.secrets.yaml

          # Stage the host key in the layout nixos-anywhere copies to the new
          # root filesystem. Without this the installer generates a new host key
          # that cannot decrypt the sops secrets.
          extra_files=$(mktemp -d)
          trap 'rm -rf "$extra_files"' EXIT
          install -Dm600 "$host_key" "$extra_files/etc/ssh/ssh_host_ed25519_key"
          install -Dm644 "$host_pub" "$extra_files/etc/ssh/ssh_host_ed25519_key.pub"

          ${nixos-anywhere.packages.${system}.default}/bin/nixos-anywhere \
            --flake "$repo_root#server" \
            --target-host "$target_host" \
            --ssh-option UserKnownHostsFile=/dev/null \
            --ssh-option StrictHostKeyChecking=no \
            -i "$identity_file" \
            --extra-files "$extra_files"
        '';
      };
      nixosConfigurations = createNixosConfigurations {
        bootable = ./hosts/bootable;
        nixos = ./hosts/desktop;
        server = ./hosts/server;
      };
      homeModules = {
        waynevanson = ./home-manager/profiles/waynevanson;
      };
      homeConfigurations = createHomeConfigurations {
        inherit (self.homeModules) waynevanson;
      };
      packages.${system} = (createPackages {
        bitwig = ./packages/bitwig.nix;
        catppuccin-forgejo-themes = ./packages/catppuccin-forgejo-themes;
        codelens = ./packages/codelens;
        pi-catppuccin-themes = ./packages/pi-catppuccin-themes;
        pi-coding-agent = ./packages/pi-coding-agent;
        pi-config-extensions = ./packages/pi-config-extensions;
      });
      nixosModules = {
        custom = ./modules/custom;
        sops = ./modules/sops.nix;
      };
    };
}
