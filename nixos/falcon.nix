{ pkgs, ... }:
let
  falcon = pkgs.callPackage ./falcon { };

  initScript = pkgs.writeScript "init-falcon" ''
    #!${pkgs.bash}/bin/sh
    set -euo pipefail

    install -d -m 0770 /opt/CrowdStrike

    if [ ! -e /opt/CrowdStrike/falcond ]; then
      cp -a ${falcon}/opt/CrowdStrike/. /opt/CrowdStrike/
      chown -R root:root /opt/CrowdStrike
    fi

    # load CID from /etc/falcon-sensor.env (root-only)
    . /etc/falcon-sensor.env

    # set CID via falconctl inside FHS env
    /opt/CrowdStrike/falconctl -s -f --cid=\"$FALCON_CID\"

    # sanity print
    /opt/CrowdStrike/falconctl -g --cid
  '';
in {
  systemd.tmpfiles.rules = [
    "d /opt/CrowdStrike 0770 root root -"
  ];

  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor";
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      DefaultDependencies = false;

      # Avoid systemd giving up during flapping
      StartLimitIntervalSec = 0;
      StartLimitBurst = 10;
    };

    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    before = [ "sysinit.target" "shutdown.target" ];

    serviceConfig = {
      Type = "forking";
      PIDFile = "/run/falcond.pid";
      ExecStartPre = initScript;
      ExecStart = "${falcon}/bin/fs-bash -c \"/opt/CrowdStrike/falcond\"";

      Restart = "on-failure";
      RestartSec = "15s";

      TimeoutStopSec = "60s";
      KillMode = "process";
      Delegate = true;
    };
  };
}

