# ─────────────────────────────────────────────────────────────
# Starship プロンプト
#
# 元の dotfiles では fish 側で pure を使いつつ starship.toml も
# 持っている。ここでは Nix 側に統一して starship を有効化する。
# ─────────────────────────────────────────────────────────────
{ ... }:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    settings = {
      # 余計な情報を切る
      add_newline = false;

      python = {
        python_binary = "python";
      };

      # Git ブランチ表示は repo 内のときだけ
      git_branch = {
        only_attached = true;
      };
    };
  };
}
