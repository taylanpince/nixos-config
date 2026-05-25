{ pkgs }:

# nixpkgs marks `cocoapods` as darwin-only and refuses to evaluate it on Linux,
# so we ship ruby + bundler and install the `pod` gem to ~/.gem on first use:
#   gem install --user-install cocoapods
# Pod authoring and `pod trunk push` work on Linux; `pod lib lint` does not
# (it invokes xcodebuild, which is macOS-only).

let
  androidEnv = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "34" "35" "36" ];
    buildToolsVersions = [ "35.0.0" "36.0.0" ];
    includeEmulator = false;
    includeSystemImages = false;
    includeNDK = false;
    includeSources = false;
  };
  androidSdk = androidEnv.androidsdk;
in
{
  mobile = pkgs.mkShell {
    name = "mobile";
    packages = [
      pkgs.jdk21
      pkgs.gradle
      pkgs.kotlin
      pkgs.ruby
      pkgs.bundler
      pkgs.curl
      pkgs.git
      androidSdk
    ];

    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/36.0.0/aapt2";

    # cocoapods → typhoeus → ethon → FFI dlopens libcurl by SONAME, which
    # isn't on a default search path on NixOS.
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.curl ];

    shellHook = ''
      export GEM_HOME="$(ruby -e 'puts Gem.user_dir')"
      export PATH="$GEM_HOME/bin:$PATH"
    '';
  };
}
