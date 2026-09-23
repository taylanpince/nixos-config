{ pkgs, pkgsLlm }:

let
  agent-deck = pkgs.stdenv.mkDerivation rec {
    pname = "agent-deck";
    version = "1.16.16";

    src = pkgs.fetchurl {
      url = "https://github.com/asheshgoplani/agent-deck/releases/download/v${version}/agent-deck_${version}_linux_amd64.tar.gz";
      sha256 = "0mp1xkzay18si7xgydk4s9mhlfxbslcmvisxhc0l04lgcpwsjiq2";
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
