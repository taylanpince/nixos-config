{ pkgs, ... }:

{
  nixpkgs.config.joypixels.acceptLicense = true;

  fonts = {
    fontconfig.enable = true;

    packages = with pkgs; [
      inter
      nerd-fonts.jetbrains-mono
      joypixels
      noto-fonts-color-emoji # fallback for missing glyphs
    ];

    fontconfig.defaultFonts.emoji = [
      "JoyPixels"
      "Noto Color Emoji"
    ];
  };
}
