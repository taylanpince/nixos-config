{ pkgs, pkgsLlm }:

let
  agent-deck = pkgs.stdenv.mkDerivation rec {
    pname = "agent-deck";
    version = "1.9.47";

    src = pkgs.fetchurl {
      url = "https://github.com/asheshgoplani/agent-deck/releases/download/v${version}/agent-deck_${version}_linux_amd64.tar.gz";
      sha256 = "1f2q1n55xs89b7gdnsbln8p6r1yc9q0xrz3fv83z850p5ib150r3";
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
    packages = [
      pkgs.nodejs_24
      # AI CLIs come from pkgsLlm (independent nixpkgs pin — see flake.nix)
      pkgsLlm.claude-code
      pkgsLlm.codex
      agent-deck
    ];
  };
}
