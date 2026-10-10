#!/usr/bin/env bash
# Compile only: no installation, module loading, boot entry or system rebuild.
# Pinned to the source/build files of the investigated NixOS kernel.
set -euo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
archive=/nix/store/qdb5ymc1mx7k19rqdi6qaqsz6l0jv359-linux-6.18.44.tar.xz
dev=/nix/store/r4z3nvwwwbg9x9lxddbdjbkbpi5sgnin-linux-6.18.44-dev
compiler=/nix/store/7sh9061yj9yl20ndc00rqw4d0bd80m1j-gcc-15.3.0/bin/gcc
linker=/nix/store/8lkj89binl0xhraqxb8bwmv0q4p3pnlr-binutils-2.46/bin/ld
for input in "$archive" "$dev/lib/modules/6.18.44/build/Makefile" "$compiler" "$linker"; do
  [[ -r $input ]] || { echo "Missing build input: $input; see LOCAL-ENGINEERING.md." >&2; exit 1; }
done
printf '%s  %s\n' 0f72d938f06828e82c90405174fe572287db7bfe089e2fc46572a99a7f240d43 "$archive" | sha256sum --check --status
umask 077
work=$(mktemp -d "$project/evidence/ucsi-build-XXXXXX")
printf 'Build directory: %s\n' "$work"
tar -xJf "$archive" -C "$work" --strip-components=1 linux-6.18.44/drivers/usb/typec/ucsi
patch -p1 -d "$work" < "$project/patches/0001-ucsi-restore-command-completion-tracing.patch"
make -C "$dev/lib/modules/6.18.44/build" M="$work/drivers/usb/typec/ucsi" \
  CC="$compiler" LD="$linker" -j4 typec_ucsi.ko 2>&1 | tee "$work/build.log"
modinfo "$work/drivers/usb/typec/ucsi/typec_ucsi.ko" > "$work/modinfo.txt"
sha256sum "$work/drivers/usb/typec/ucsi/typec_ucsi.ko" > "$work/module.sha256"
printf 'COMPILED ONLY: %s\n' "$work/drivers/usb/typec/ucsi/typec_ucsi.ko"
