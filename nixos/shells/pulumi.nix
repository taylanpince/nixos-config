{ pkgs, pkgsPulumi }:
{
  pulumi = pkgs.mkShell {
    name = "pulumi";
    packages = [
      # Pulumi comes from pkgsPulumi (independent nixpkgs pin — see flake.nix)
      pkgsPulumi.pulumi-bin
      pkgsPulumi.pulumiPackages.pulumi-nodejs

      pkgs.nodejs_22
      pkgs.pnpm
      pkgs.typescript
      pkgs.typescript-language-server
      pkgs.go

      pkgs.google-cloud-sdk
    ];
  };
}
