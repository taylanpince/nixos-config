{ pkgs }:

let
  kurtosis-cli = pkgs.stdenv.mkDerivation rec {
    pname = "kurtosis-cli";
    version = "1.20.0";

    src = pkgs.fetchzip {
      url = "https://github.com/kurtosis-tech/kurtosis-cli-release-artifacts/releases/download/${version}/kurtosis-cli_${version}_linux_amd64.tar.gz";
      hash = "sha256-COXMUNYeQxB1FDqQGnfL1sOaxon1Gx1Pd/69uRYAHAE=";
      stripRoot = false;
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 kurtosis $out/bin/kurtosis
      installShellCompletion --cmd kurtosis \
        --bash scripts/completions/scripts/kurtosis.bash \
        --fish scripts/completions/scripts/kurtosis.fish \
        --zsh scripts/completions/scripts/kurtosis.zsh
      runHook postInstall
    '';

    nativeBuildInputs = [ pkgs.installShellFiles ];

    meta = {
      description = "Kurtosis CLI for defining and running distributed system environments";
      homepage = "https://www.kurtosis.com";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "kurtosis";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  kurtosis = pkgs.mkShell {
    name = "kurtosis";
    packages = [
      kurtosis-cli
      pkgs.yq-go
      pkgs.bats
    ];
  };
}
