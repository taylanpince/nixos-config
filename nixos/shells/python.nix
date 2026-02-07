{ pkgs }:
{
  python = pkgs.mkShell {
    packages = with pkgs; [
      python3
      uv
      ruff
    ];
  };
}

