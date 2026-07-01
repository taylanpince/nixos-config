{ pkgs }:
{
  node = pkgs.mkShell {
    name = "node";
    packages = with pkgs; [
      nodejs_24
      pnpm
      yarn
      typescript
      typescript-language-server
      wrangler
    ];
  };
}

