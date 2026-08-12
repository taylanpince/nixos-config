{ pkgs }:
let
  # Wrangler pinned ahead of nixpkgs via prebuilt npm tarball.
  # See ../pkgs/wrangler/default.nix for the bump procedure.
  wrangler-latest = pkgs.callPackage ../pkgs/wrangler { };
in
{
  node = pkgs.mkShell {
    name = "node";
    packages = with pkgs; [
      nodejs_24
      pnpm
      yarn
      bun
      typescript
      typescript-language-server
      wrangler-latest
    ];
  };
}

