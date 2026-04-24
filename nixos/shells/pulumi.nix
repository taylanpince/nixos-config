{ pkgs }:
{
  pulumi = pkgs.mkShell {
    name = "pulumi";
    packages = with pkgs; [
      pulumi-bin
      pulumiPackages.pulumi-nodejs

      nodejs_22
      nodePackages.pnpm
      nodePackages.typescript
      nodePackages.typescript-language-server
      go
    ];
  };
}

