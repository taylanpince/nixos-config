{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
  autoPatchelfHook,
  stdenv,
  llvmPackages,
  cacert,
}:
# Wrangler pinned to an npm version newer than nixpkgs currently ships.
# We install the prebuilt npm tarball (it already contains wrangler-dist/), so
# there is no source build — just fetch node_modules and wrap the bin.
#
# Bump procedure:
#   cd nixos/pkgs/wrangler
#   npm install wrangler@<new-version> --package-lock-only --ignore-scripts
#   nix build ../..#devShells.x86_64-linux.node    # copy npmDepsHash from error
buildNpmPackage rec {
  pname = "wrangler";
  version = "4.110.0";

  src = ./.;

  npmDepsHash = "sha256-Z3mUrgDxObHLp3C9s585Mfy9vpHDMzhYFEc9W9GZ40U=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # workerd (bundled via miniflare) is a prebuilt binary that needs libc++.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    llvmPackages.libcxx
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,lib/node_modules}
    cp -r node_modules/. $out/lib/node_modules/
    makeWrapper ${lib.getExe nodejs} $out/bin/wrangler \
      --inherit-argv0 \
      --prefix NODE_PATH : "$out/lib/node_modules" \
      --add-flags $out/lib/node_modules/wrangler/bin/wrangler.js \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';

  meta = {
    description = "Command-line interface for all things Cloudflare Workers (npm-pinned)";
    homepage = "https://github.com/cloudflare/workers-sdk";
    license = with lib.licenses; [ mit apsl20 ];
    mainProgram = "wrangler";
    platforms = nodejs.meta.platforms;
  };
}
