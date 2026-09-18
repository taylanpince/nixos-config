{ ... }:

{
  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "500M";
  };
}
