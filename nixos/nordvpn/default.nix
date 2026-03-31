{ stdenv
, lib
, dpkg
, autoPatchelfHook
, iptables
, iproute2
, procps
, cacert
, zlib
, sqlite
, wireguard-tools
, libnl
, libcap_ng
, ...
}:
let
  pname = "nordvpn";
  version = "4.5.0";
  arch = "amd64";

  src = builtins.path {
    path = ./${pname}_${version}_${arch}.deb;
    name = "${pname}_${version}_${arch}.deb";
  };
in
stdenv.mkDerivation {
  name = pname;
  inherit version arch src;

  nativeBuildInputs = [ dpkg autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib zlib sqlite.out libnl libcap_ng ];
  sourceRoot = ".";

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out/bin $out/sbin $out/lib/nordvpn

    cp usr/bin/nordvpn $out/bin/
    cp usr/sbin/nordvpnd $out/sbin/

    # shared libs — keep in lib/nordvpn, we set RPATH
    cp usr/lib/nordvpn/*.so $out/lib/nordvpn/

    # helper binaries nordvpnd expects at /usr/lib/nordvpn/
    cp usr/lib/nordvpn/nordfileshare $out/lib/nordvpn/
    cp usr/lib/nordvpn/norduserd $out/lib/nordvpn/
    cp usr/lib/nordvpn/openvpn $out/lib/nordvpn/
  '';

  # autoPatchelfHook will fix the interpreter and RPATH for ELF binaries.
  # We also need to tell it where the nordvpn .so files are.
  postFixup = ''
    patchelf --add-rpath $out/lib/nordvpn $out/bin/nordvpn
    patchelf --add-rpath $out/lib/nordvpn $out/sbin/nordvpnd
    patchelf --add-rpath $out/lib/nordvpn $out/lib/nordvpn/nordfileshare || true
    patchelf --add-rpath $out/lib/nordvpn $out/lib/nordvpn/norduserd || true
    patchelf --add-rpath $out/lib/nordvpn $out/lib/nordvpn/openvpn || true
  '';

  meta = with lib; {
    description = "NordVPN CLI client";
    homepage = "https://nordvpn.com";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
