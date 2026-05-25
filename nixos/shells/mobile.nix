{ pkgs }:

# nixpkgs marks `cocoapods` as darwin-only and refuses to evaluate it on Linux,
# so we ship ruby + bundler and install the `pod` gem to ~/.gem on first use:
#   gem install --user-install cocoapods
# Pod authoring and `pod trunk push` work on Linux; `pod lib lint` does not
# (it invokes xcodebuild, which is macOS-only).

{
  mobile = pkgs.mkShell {
    name = "mobile";
    packages = with pkgs; [
      jdk21
      gradle
      kotlin
      ruby
      bundler
      curl
      git
    ];

    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";

    # cocoapods → typhoeus → ethon → FFI dlopens libcurl by SONAME, which
    # isn't on a default search path on NixOS.
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.curl ];

    shellHook = ''
      export GEM_HOME="$(ruby -e 'puts Gem.user_dir')"
      export PATH="$GEM_HOME/bin:$PATH"
    '';
  };
}
