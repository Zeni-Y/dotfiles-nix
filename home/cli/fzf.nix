# fzf: あいまい検索。bash/fish に統合
{ ... }:

{
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
  };
}
