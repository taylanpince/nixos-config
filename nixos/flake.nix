{
  description = "NixOS system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Independent pin used ONLY by the `llm` devshell (claude-code, codex).
    # Kept separate so bumping AI CLIs never drags the system nixpkgs along.
    # Bump with: nix flake update --update-input nixpkgs-llm
    nixpkgs-llm.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Independent pin used ONLY for the kernel (linuxPackages_6_18).
    # Lets us track the latest 6.18.x point release (CVE backports)
    # without dragging the rest of the system off its pin. Staying on the
    # 6.18 series keeps CrowdStrike Falcon eBPF working; a new series does not.
    # Bump with: nix flake update nixpkgs-kernel
    nixpkgs-kernel.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    voxtype = {
      url = "github:peteonrails/voxtype/v1.0.0-rc1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop for Linux. Repackages Anthropic's official Linux .deb
    # for NixOS (v3.0.0+). Provides overlays.default with `claude-desktop`
    # and `claude-desktop-fhs` (FHS variant needed for MCP server support).
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-llm, nixpkgs-kernel, home-manager, voxtype, claude-desktop, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      pkgsLlm = import nixpkgs-llm {
        inherit system;
        config.allowUnfree = true;
      };

      # Kernel-only pin: newest 6.18.x point release, isolated from the
      # system nixpkgs. Consumed by modules/boot.nix via specialArgs.
      pkgsKernel = import nixpkgs-kernel {
        inherit system;
        config.allowUnfree = true;
      };

      goShells = import ./shells/go.nix { inherit pkgs; };
      pyShells = import ./shells/python.nix { inherit pkgs; };
      nodeShells = import ./shells/node.nix { inherit pkgs; };
      pulumiShells = import ./shells/pulumi.nix { inherit pkgs; };
      postgresShells = import ./shells/postgres.nix { inherit pkgs; };
      rustShells = import ./shells/rust.nix { inherit pkgs; };
      llmShells = import ./shells/llm.nix { inherit pkgs pkgsLlm; };
      mobileShells = import ./shells/mobile.nix { inherit pkgs; };
      kurtosisShells = import ./shells/kurtosis.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.bloomware = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { kernelPackages = pkgsKernel.linuxPackages_6_18; };
        modules = [
          ./configuration.nix

          # Make `pkgs.claude-desktop` / `pkgs.claude-desktop-fhs` available.
          { nixpkgs.overlays = [ claude-desktop.overlays.default ]; }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit voxtype; };
            home-manager.users.taylan = import ./home/taylan.nix;
          }
        ];
      };

      devShells.${system} =
        goShells
        // pyShells
        // nodeShells
        // pulumiShells
        // postgresShells
        // rustShells
        // llmShells
        // mobileShells
        // kurtosisShells;
    };
}
