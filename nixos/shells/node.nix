{ pkgs }:
{
  node = pkgs.mkShell {
    packages = with pkgs; [
      nodejs_22
      nodePackages.pnpm
      yarn
      nodePackages.typescript
      nodePackages.typescript-language-server
    ];
  };
}

