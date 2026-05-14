{ pkgs }:

{
  llm = pkgs.mkShell {
    name = "llm";
    packages = with pkgs; [
      nodejs_24
      claude-code
      codex
      (writeShellScriptBin "ccmanager" ''
        export PATH="${pkgs.nodejs_24}/bin:$PATH"
        exec npx -y ccmanager@4.1.17 "$@"
      '')
    ];
  };
}
