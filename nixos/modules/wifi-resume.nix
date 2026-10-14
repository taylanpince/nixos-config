# Wi-Fi doesn't always come back after suspend. On 2026-10-13, after ten hours asleep, iwd stayed
# "disconnected" and never tried to reconnect, so the machine had no network until a reboot (the
# card is a MediaTek mt7925e, known for flaky resumes on Linux).
#
# After every resume this waits for a connection. If there's none after 30s it restarts iwd
# (NetworkManager re-attaches to it), and if that doesn't help either it reloads the Wi-Fi driver.
# It does nothing when the network is already up, Wi-Fi is switched off, or a wired link is active.
# Watch it with: journalctl -u wifi-resume
{ pkgs, ... }:

let
  driver = "mt7925e";
  sleepTargets = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
  check = pkgs.writeShellApplication {
    name = "wifi-resume";
    runtimeInputs = [ pkgs.networkmanager pkgs.kmod pkgs.systemd pkgs.coreutils pkgs.gawk ];
    text = ''
      connected() {
        nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '($1 == "wifi" || $1 == "ethernet") && $2 == "connected" { found = 1 } END { exit !found }'
      }
      wait_for() { # seconds
        for _ in $(seq "$1"); do
          connected && return 0
          sleep 1
        done
        return 1
      }

      if [ "$(nmcli radio wifi 2>/dev/null)" != "enabled" ]; then
        echo "Wi-Fi is switched off; nothing to do"
        exit 0
      fi
      if wait_for 30; then
        echo "network back after resume"
        exit 0
      fi

      echo "no network 30s after resume; restarting iwd"
      systemctl restart iwd.service
      if wait_for 30; then
        echo "network back after restarting iwd"
        exit 0
      fi

      echo "still no network; reloading ${driver} and restarting iwd"
      systemctl stop iwd.service
      modprobe -r ${driver} || echo "couldn't unload ${driver}"
      sleep 2
      modprobe ${driver}
      sleep 2
      systemctl start iwd.service
      if wait_for 45; then
        echo "network back after reloading ${driver}"
        exit 0
      fi
      echo "still no network after reloading ${driver}; a reboot may be needed"
      exit 1
    '';
  };
in
{
  systemd.services.wifi-resume = {
    description = "Bring Wi-Fi back after resume if it didn't reconnect";
    after = sleepTargets;
    wantedBy = sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${check}/bin/wifi-resume";
      TimeoutStartSec = "3min";
    };
  };
}
