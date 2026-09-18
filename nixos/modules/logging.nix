{ ... }:

{
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=500M
  '';
}
