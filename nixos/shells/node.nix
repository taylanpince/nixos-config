{ pkgs }:
{
  node = pkgs.mkShell {
    packages = with pkgs; [
      nodejs_24
      nodePackages.pnpm
      yarn
      nodePackages.typescript
      nodePackages.typescript-language-server
      wrangler
    ];
  };
}

