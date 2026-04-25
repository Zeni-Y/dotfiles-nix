# gh: GitHub 公式 CLI
{ ... }:

{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
