# CrowdStrike Falcon + Kolide Setup

This documents the **manual steps** I did outside of Nix, the **debugging workflow**, and the small Nix change needed to **automate Kolide’s “CrowdStrike installed” check** on NixOS.

> Context: Company instructions assume Ubuntu/Debian. I kept NixOS and made both agents work anyway.
>
> - CrowdStrike is running and enrolled (**AID is set**).
> - Kolide is running and enrolled.
> - Kolide compliance required “CrowdStrike installed and running”.
>
> NixOS has no dpkg database, so Kolide’s osquery `deb_packages` check needed a dpkg-status shim.

---

## Configuration

### Automated (in Nix config)

- Kolide launcher service enabled via `kolide.nix` module import.
- CrowdStrike Falcon service and its FHS wrapper setup ([via this gist](https://gist.github.com/klDen/c90d9798828e31fecbb603f85e27f4f1)) in `falcon.nix`.

### Manual (outside Nix)

- **Extract Kolide enrollment secret** from the company-provided `.deb` and write it to:
  - `/etc/kolide-k2/secret` (root:root, `0600`)
- **One-time cleanup** of `/opt/CrowdStrike` so the symlink-based setup can take over cleanly.
- **dpkg status shim** at `/var/lib/dpkg/status` so Kolide’s osquery `deb_packages` check reports `falcon-sensor` installed.

---

## Prerequisites

### Files you need from IT

- CrowdStrike Falcon sensor `.deb` (matching the version IT expects).
- Kolide launcher `.deb` (tenant-specific; contains the enrollment secret).
- Falcon CID (as provided by IT).

### Packages used for debugging/extraction (one-off)

These can be run without installing permanently:

- `dpkg-deb` (from `dpkg`) to unpack `.deb`
- `osqueryi` (from `osquery`) to query Kolide’s osquery socket

Run one-offs like:

```bash
nix-shell -p dpkg --run 'dpkg-deb --version'
nix-shell -p osquery --run 'osqueryi --version'
```

---

## Manual steps

### 1) Kolide: extract and install enrollment secret

1. Extract the Kolide `.deb` payload and pull the secret:

```bash
mkdir -p /tmp/kolide-deb
nix-shell -p dpkg --run 'dpkg-deb -x ~/Downloads/kolide-launcher.deb /tmp/kolide-deb'
cat /tmp/kolide-deb/etc/kolide-k2/secret
```

1. Install secret to the expected location:

```bash
sudo install -d -m 755 /etc/kolide-k2
sudo sh -c 'cat /tmp/kolide-deb/etc/kolide-k2/secret > /etc/kolide-k2/secret'
sudo chown root:root /etc/kolide-k2/secret
sudo chmod 600 /etc/kolide-k2/secret
```

1. Restart Kolide:

```bash
sudo systemctl restart kolide-launcher
```

---

### 2) CrowdStrike: one-time cleanup of `/opt/CrowdStrike`

If you previously unpacked the Falcon `.deb` manually into `/opt/CrowdStrike`, and you later switch to the **symlink/FHS wrapper** approach, you can hit errors like:

- `ln: /opt/CrowdStrike/ASPM: cannot overwrite directory`

Fix is a one-time cleanup:

```bash
sudo systemctl stop falcon-sensor || true
sudo rm -rf /opt/CrowdStrike
sudo mkdir -p /opt/CrowdStrike
sudo chown root:root /opt/CrowdStrike
sudo chmod 0770 /opt/CrowdStrike
sudo systemctl start falcon-sensor
```

---

### 3) Kolide compliance: “CrowdStrike installed” on NixOS (dpkg status shim)

Many orgs implement the CrowdStrike requirement by checking osquery’s **`deb_packages`** table, which is empty on NixOS because there’s **no dpkg database**.

I created a minimal dpkg status entry so `deb_packages` reports `falcon-sensor` installed:

```bash
sudo mkdir -p /var/lib/dpkg
sudo tee /var/lib/dpkg/status >/dev/null <<'EOF'
Package: falcon-sensor
Status: install ok installed
Priority: optional
Section: misc
Installed-Size: 0
Maintainer: CrowdStrike
Architecture: amd64
Version: 7.31.0-18410
Description: CrowdStrike Falcon Sensor (shim for Kolide/osquery on NixOS)
EOF
sudo chmod 644 /var/lib/dpkg/status
sudo chown root:root /var/lib/dpkg/status
```

Then verify from osquery (see Debugging section).

---

## Debugging

### CrowdStrike sanity checks

**Service + logs**

```bash
systemctl status falcon-sensor --no-pager
journalctl -u falcon-sensor -b --no-pager | tail -200
```

**Enrollment status**

```bash
sudo /opt/CrowdStrike/falconctl -g --aid
sudo /opt/CrowdStrike/falconctl -g --cid
sudo /opt/CrowdStrike/falconctl -g --rfm-state
sudo /opt/CrowdStrike/falconctl -g --rfm-reason
```

✅ Success indicator: **AID is set**.

**Connectivity spot-check**

```bash
curl -Iv https://ts01-lanner-lion.cloudsink.net
```

---

### Kolide: find the osquery socket

Kolide runs osquery and exposes a Unix socket under `/var/kolide-k2/...`.

Find it:

```bash
sudo find /var -type s 2>/dev/null | grep -i osquery
```

Example socket path:

```
/var/kolide-k2/k2device.kolide.com/osquery-XXXXXXXX.sock
```

---

### Kolide: run osquery queries against Kolide’s socket

Connect to the socket using `osqueryi`:

```bash
nix-shell -p osquery --run 'sudo osqueryi --socket /var/kolide-k2/k2device.kolide.com/osquery-XXXXXXXX.sock'
```

#### Confirm CrowdStrike processes are visible

```sql
select name, pid, cmdline from processes where name like "%falcon%";
```

Expected output includes `falcond` and likely `falcon-sensor-bpf`.

#### Discover systemd_units schema (columns vary)

```sql
.schema systemd_units
```

Then query with the correct column names. For example, if the table has `id`:

```sql
select id, active_state, sub_state, fragment_path
from systemd_units
where id like "%falcon%";
```

#### Confirm “installed” via deb_packages

```sql
select name, version from deb_packages where name = "falcon-sensor";
```

If this returns nothing on NixOS, Kolide will likely fail “installed” checks unless you add the dpkg status shim.

---

## Automating the dpkg status shim (add to `kolide.nix`)

Add the following to `kolide.nix` (or wherever you want this to live). This uses **systemd tmpfiles** to create the dpkg admin dir and a stable `/var/lib/dpkg/status` entry on boot/rebuild.

```nix
systemd.tmpfiles.rules = [
  "d /var/lib/dpkg 0755 root root -"
  "f /var/lib/dpkg/status 0644 root root - Package: falcon-sensor\nStatus: install ok installed\nPriority: optional\nSection: misc\nInstalled-Size: 0\nMaintainer: CrowdStrike\nArchitecture: amd64\nVersion: 7.31.0-18410\nDescription: CrowdStrike Falcon Sensor (shim for Kolide/osquery on NixOS)\n"
];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

And verify via osquery:

```sql
select name, version from deb_packages where name = "falcon-sensor";
```

> Note: This shim is only meant to satisfy Kolide’s **Debian-package-based** compliance check. NixOS does not actually use dpkg.
