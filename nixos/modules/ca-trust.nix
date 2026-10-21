{ ... }:

{
  # eMudhra intermediate compromise (2026-10-20): EM DV TLS CA - G3B chains to
  # this root via emSign Root TLS CA - G3. Patched NSS (3.131.1) isn't in
  # nixpkgs yet, so drop the root from the system bundle until cacert catches
  # up. Covers curl/OpenSSL, git, Go, Python and Node (nixpkgs builds both
  # against the system store). Remove once cacert >= 3.131.1.
  # Test: curl https://dv-g3b-emudhra.we-have-a-problem.com/ must fail.
  security.pki.caCertificateBlacklist = [ "emSign ECC Root CA - G3" ];

  # uv defaults to its bundled webpki-roots, which still trust the root above.
  # Make it use the system bundle instead.
  environment.sessionVariables.UV_NATIVE_TLS = "1";
}
