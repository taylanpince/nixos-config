{ pkgs, ... }:
let
  falcon = pkgs.callPackage ./falcon { };

  initScript = pkgs.writeScript "init-falcon" ''
    #!${pkgs.bash}/bin/sh
    set -euo pipefail

    rm -rf /opt/CrowdStrike
    mkdir -p /opt/CrowdStrike
    chmod 0770 /opt/CrowdStrike
    ln -s ${falcon}/opt/CrowdStrike/* /opt/CrowdStrike/

    # load CID from /etc/falcon-sensor.env (root-only)
    . /etc/falcon-sensor.env

    # set CID via falconctl inside FHS env
    ${falcon}/bin/fs-bash -c "/opt/CrowdStrike/falconctl -s -f --cid=\"$FALCON_CID\""

    # sanity print
    ${falcon}/bin/fs-bash -c "/opt/CrowdStrike/falconctl -g --cid"
  '';
in {
  systemd.tmpfiles.rules = [
    "d /opt/CrowdStrike 0770 root root -"
  ];

  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor";
    wantedBy = [ "multi-user.target" ];

    unitConfig.DefaultDependencies = false;
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    before = [ "sysinit.target" "shutdown.target" ];

    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/falcond.pid";
      ExecStartPre = initScript;
      ExecStart = "${falcon}/bin/fs-bash -c \"/opt/CrowdStrike/falcond\"";
      Restart = "no";
      TimeoutStopSec = "60s";
      KillMode = "process";
      Delegate = true;
    };
  };
}

