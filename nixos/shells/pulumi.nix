{ pkgs }:
{
  pulumi = pkgs.mkShell {
    name = "pulumi";
    packages = with pkgs; [
      pulumi-bin
      pulumiPackages.pulumi-nodejs

      nodejs_22
      pnpm
      typescript
      typescript-language-server
      go
    ];
  };
}

