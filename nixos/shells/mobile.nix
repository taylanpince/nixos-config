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
    ];

    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";

    shellHook = ''
      export GEM_HOME="$HOME/.gem"
      export PATH="$GEM_HOME/bin:$PATH"
    '';
  };
}
