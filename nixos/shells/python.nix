{ pkgs }:
{
  python = pkgs.mkShell {
    packages = with pkgs; [
      python3
      uv
      ruff
    ];
  };

  python311 = pkgs.mkShell {
    packages = with pkgs; [
      python311
      uv
      ruff
    ];
  };
}

