{ pkgs, ... }:
let
  nordvpn = pkgs.callPackage ./nordvpn { };

  initScript = pkgs.writeScript "init-nordvpn" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # nordvpnd expects helper binaries at /usr/lib/nordvpn/
    mkdir -p /usr/lib/nordvpn
    ln -sf ${nordvpn}/lib/nordvpn/* /usr/lib/nordvpn/
  '';
in {
  users.groups.nordvpn = {};

  networking.firewall.checkReversePath = false;

  systemd.tmpfiles.rules = [
    "d /run/nordvpn 0770 root nordvpn -"
    "d /var/lib/nordvpn 0770 root nordvpn -"
  ];

  systemd.services.nordvpnd = {
    description = "NordVPN Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    path = with pkgs; [
      iptables
      iproute2
      procps
      wireguard-tools
    ];

    serviceConfig = {
      ExecStartPre = initScript;
      ExecStart = "${nordvpn}/sbin/nordvpnd";
      Group = "nordvpn";
      RuntimeDirectory = "nordvpn";
      RuntimeDirectoryMode = "0770";
      KillMode = "process";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nordvpn" ''
      exec ${nordvpn}/bin/nordvpn "$@"
    '')
    (pkgs.writeShellScriptBin "vpnon" ''
      exec ${nordvpn}/bin/nordvpn connect uk1665
    '')
  ];
}
