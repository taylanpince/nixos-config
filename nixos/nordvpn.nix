{ pkgs, ... }:
let
  nordvpn = pkgs.callPackage ./nordvpn { };
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

    serviceConfig = {
      ExecStart = "${nordvpn}/bin/nordvpn-bash -c /sbin/nordvpnd";
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
      exec ${nordvpn}/bin/nordvpn-bash -c "/bin/nordvpn $*"
    '')
    (pkgs.makeDesktopItem {
      name = "nordvpn";
      desktopName = "NordVPN";
      comment = "NordVPN callback handler";
      icon = "nordvpn";
      mimeTypes = [ "x-scheme-handler/nordvpn" ];
      exec = "nordvpn click %u";
      terminal = true;
      noDisplay = true;
    })
  ];
}
