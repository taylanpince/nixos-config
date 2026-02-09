{ pkgs }:
{
  pulumi = pkgs.mkShell {
    packages = with pkgs; [
      pulumi

      nodejs_22
      nodePackages.pnpm
      nodePackages.typescript
      nodePackages.typescript-language-server
      go
    ];
  };
}

