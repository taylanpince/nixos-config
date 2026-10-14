# Fedora USB preparation for this investigation

Official Fedora Workstation 44 x86_64 image, build 1.7, downloaded 10 October 2026 from Fedora's download service. Image size: 2,851,612,672 bytes.

SHA256: `1620295f6a00c27c3208f0c00b8ece4eab1ec69b9002152d97488bf26a426ddf`.

Signed checksum verified using Fedora 44 key fingerprint `36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6`, matched against the [official fingerprint](https://fedoraproject.org/security/). Image hash matches the verified checksum and the [download page](https://fedoraproject.org/workstation/download/). Files and verification records are in `../evidence/fedora-media/`.

Target identified read-only: Kingston DataTraveler 3.0, advertised 64 GB (61,991,813,120 bytes), serial `E0D55E6CBD05196139C100F4`, currently `/dev/sda`. Stable target:

```text
/dev/disk/by-id/usb-Kingston_DataTraveler_3.0_E0D55E6CBD05196139C100F4-0:0
```

It currently contains Ubuntu Server 26.04 and an ext4 partition labeled `writable`; none were mounted during preflight. Writing Fedora replaces the drive's existing layout/content. The internal NVMe is not a target.

The owner runs this locally when ready to erase that Kingston:

```bash
sudo bash /home/taylan/config/lg-ultrafine-5k-debug/scripts/write-fedora-usb.sh --write
```

The script verifies the image, checks USB identity/capacity/removability and absence of mounts/holders/swap, then asks for `ERASE KINGSTON`. It writes only after that confirmation and compares the image against the device afterward. Wait for `VERIFIED`. Without `--write`, it performs read-only checks. Shell syntax and real read-only preflight passed; writing has not been performed by the agent.

Before reboot, transfer this archive to the Mac using the owner's available file-transfer method:

```text
/home/taylan/config/lg-ultrafine-5k-debug/evidence/fedora-investigation-kit.tar.gz
```

It contains only `collect.sh`, `trace.sh`, and the Fedora checklist—no raw logs, camera images or private machine data. Transfer it from the Mac into the Fedora live session, extract it in the live user's home, and run the checklist from the extracted `lg-ultrafine-5k-debug` directory. Transfer the resulting evidence back to the Mac before ending the live session. The scripts themselves do not upload anything.

Do not reboot until USB verification and transfer of the diagnostic kit to the Mac are confirmed. Then follow `FEDORA-LIVE-CHECKLIST.md`: F12 boot, live session only, internal panel enabled, LG through the same left-rear USB-C module, separate charger absent.

Boot steps after the writer prints `VERIFIED`:

1. Copy the diagnostic kit to the Mac before leaving NixOS. Save work; keep the Kingston connected and unplug LG only at the laptop. Keep the left-rear USB-C module installed and separate charger absent.
2. Shut down normally. Power on and immediately tap F12 repeatedly on the built-in keyboard, before the Framework logo. If the keyboard's function-key mode requires it, hold Fn while tapping F12.
3. In the boot menu select the Kingston USB / EFI USB Device entry, then Enter. Do not select the internal NVMe/NixOS entry.
4. Choose `Start Fedora Workstation-Live 44` and press Enter.
5. Use the live desktop. If an installer opens, close it; do not install Fedora or select an installation disk.
6. Keep LG disconnected until the disconnected baseline and trace are ready. Contact the agent from the Mac for the capture steps. The agent's current NixOS tools will not automatically run inside the Fedora session.

The F12 and Fedora boot-entry sequence is documented in [Framework's Fedora guide](https://guides.frame.work/Guide/Fedora+44+Workstation+Installation+on+the+Framework+Laptop+13/730?lang=en). No BIOS setting change is required for this test.
