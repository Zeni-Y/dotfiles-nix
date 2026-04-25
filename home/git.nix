# ─────────────────────────────────────────────────────────────
# Git 設定
#
# userName / userEmail はホストごとに上書きされる前提
# (flake.nix の userInfo で指定し、hosts/*.nix から渡している)。
# ─────────────────────────────────────────────────────────────
{ pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    extraConfig = {
      init.defaultBranch = "main";

      pull = {
        rebase = true;
      };

      rebase = {
        autoStash = true;
      };

      push = {
        autoSetupRemote = true;
      };

      color.ui = "auto";

      # GitHub CLI を credential helper に使う
      "credential \"https://github.com\"".helper = "!gh auth git-credential";
      "credential \"https://gist.github.com\"".helper = "!gh auth git-credential";

      # https でクローンしたリポジトリでも push は ssh で行う
      "url \"git@github.com:\"".pushInsteadOf = "https://github.com/";
    };

    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".Spotlight-V100"
      ".Trashes"

      # Linux
      "*~"
      ".directory"
      ".Trash-*"

      # Editors
      ".vscode/*"
      "!.vscode/settings.json"
      "!.vscode/tasks.json"
      "!.vscode/launch.json"

      # Claude Code
      ".claude/settings.local.json"
    ];
  };

  # ghq の保存先
  home.sessionVariables.GHQ_ROOT = "$HOME/ghq";
}
