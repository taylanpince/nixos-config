{ pkgs }:

let
  agent-deck = pkgs.stdenv.mkDerivation rec {
    pname = "agent-deck";
    version = "1.9.4";

    src = pkgs.fetchurl {
      url = "https://github.com/asheshgoplani/agent-deck/releases/download/v${version}/agent-deck_${version}_linux_amd64.tar.gz";
      sha256 = "17dxcnmsampjx838b9dvl6gyd2asy3hjwz050kk83670wyah5qfj";
    };

    sourceRoot = ".";

    installPhase = ''
      install -Dm755 agent-deck $out/bin/agent-deck
    '';

    meta = {
      description = "Mission control TUI for AI coding agents";
      homepage = "https://github.com/asheshgoplani/agent-deck";
      license = pkgs.lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  llm = pkgs.mkShell {
    name = "llm";
    packages = with pkgs; [
      nodejs_24
      claude-code
      codex
      agent-deck
    ];
  };
}
