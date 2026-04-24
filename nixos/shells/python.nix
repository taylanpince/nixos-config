{ pkgs }:
{
  python = pkgs.mkShell {
    name = "python";
    packages = with pkgs; [
      python3
      uv
      ruff
    ];
  };

  python311 = pkgs.mkShell {
    name = "python311";
    packages = with pkgs; [
      python311
      uv
      ruff
    ];
  };
}

