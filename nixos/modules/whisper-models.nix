{ pkgs, ... }:

# Whisper.cpp ggml models placed on disk at stable paths so scripts can point
# at them without threading env vars through every shell.  Kept out of
# voxtype's model set on purpose — voxtype is pinned to `small` for latency,
# meeting transcription runs `medium` in the background.

let
  medium = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin";
    hash = "sha256-bBTVre5fhjlAN7Tk6LWfFnO2zuEOPPCxG72+55wVYgg=";
  };
in
{
  environment.etc."whisper-models/ggml-medium.bin".source = medium;
}
