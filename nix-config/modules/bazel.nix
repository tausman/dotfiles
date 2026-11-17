{ liveLink, ... }:
{
  home.file.".bazelrc".source = liveLink "bazel/.bazelrc";
}
