# direnv: ディレクトリごとの環境変数。nix-direnv で flake-shell の自動読み込み
{ ... }:

{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };
}
