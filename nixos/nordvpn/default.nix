{ stdenv
, lib
, dpkg
, buildFHSEnv
, iptables
, iproute2
, procps
, cacert
, zlib
, sqlite
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

  nordvpn-unwrapped = stdenv.mkDerivation {
    name = pname;
    inherit version arch src;

    buildInputs = [ dpkg ];
    sourceRoot = ".";

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      mkdir -p $out/bin $out/sbin $out/lib
      cp usr/bin/nordvpn $out/bin/
      cp usr/sbin/nordvpnd $out/sbin/
      cp usr/lib/nordvpn/*.so $out/lib/
      cp usr/lib/nordvpn/nordfileshare $out/lib/
      cp usr/lib/nordvpn/norduserd $out/lib/
      cp usr/lib/nordvpn/openvpn $out/lib/
    '';

    meta = with lib; {
      description = "NordVPN CLI client";
      homepage = "https://nordvpn.com";
      license = licenses.unfree;
      platforms = platforms.linux;
    };
  };
in
buildFHSEnv {
  name = "nordvpn-bash";
  targetPkgs = pkgs: [
    nordvpn-unwrapped
    iptables
    iproute2
    procps
    cacert
    zlib
    sqlite.out
  ];

  runScript = "bash";
}
