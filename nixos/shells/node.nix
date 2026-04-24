{ pkgs }:
{
  node = pkgs.mkShell {
    name = "node";
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

