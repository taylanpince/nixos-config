{ pkgs }:

let
  wrangler = pkgs.wrangler.overrideAttrs (old: rec {
    version = "4.103.0";
    src = pkgs.fetchFromGitHub {
      owner = "cloudflare";
      repo = "workers-sdk";
      rev = "wrangler@${version}";
      hash = "sha256-u2phFQCUmmkrKoy05MHRA3rBUXwpKFlVRHI/qi3Uojg=";
    };
    pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
      inherit src;
      outputHash = "sha256-MaqocUoaHDR+orOOwPy3ta3AzzwmguebRlcMO4WCHHU=";
    });
    postBuild = ''
      mv packages/vitest-pool-workers packages/~vitest-pool-workers

      for pkg in unenv-preset workers-utils cli-shared-helpers codemod config local-explorer-ui miniflare autoconfig deploy-helpers workers-auth wrangler; do
        NODE_ENV="production" pnpm --filter "$pkg" run build
      done
    '';
  });
in
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

