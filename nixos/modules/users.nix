{ pkgs, ... }:

{
  users.users.taylan = {
    isNormalUser = true;
    description = "Taylan Pince";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" ];
    packages = with pkgs; [
      # user-specific packages can go here
    ];
  };
}
