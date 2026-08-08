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

    settings = {
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

  # ─────────────────────────────────────────────────────────────
  # git の短縮入力 (fish の abbreviation)
  #
  # alias ではなく abbr を使う。abbr はスペース / Enter を打った瞬間に
  # コマンドラインの文字列そのものを展開するため:
  #   - 画面にも履歴にも `git status --short --branch` が残る
  #     (後から履歴を辿ったとき何をしたのか分かる)
  #   - 展開後にその場でオプションを足したり消したりできる
  #   - 補完は展開後の `git ...` に対して効くので、fish 内蔵の
  #     git 補完 (ブランチ名やオプションの説明) がそのまま使える
  # alias でこれをやると別コマンドとして扱われ、補完を効かせるのに
  # --wraps が要るうえ履歴には短縮形しか残らない。
  #
  # 既定の position は "command" なので、コマンド先頭以外に出てくる
  # 同じ綴り (`echo gd` の gd など) は展開されない。
  # 一覧は `abbr --show`。fish 専用の機能なので bash では効かない。
  # ─────────────────────────────────────────────────────────────
  programs.fish.shellAbbrs = {
    # 状態確認
    gst = "git status --short --branch";
    gd = "git diff";
    gds = "git diff --staged";
    gl = "git log --oneline --graph --decorate --max-count=20";

    # 記録
    ga = "git add";
    gaa = "git add --all";
    gc = "git commit";
    # % の位置にカーソルが来るので、展開後そのままメッセージを打てる。
    gcm = {
      expansion = ''git commit -m "%"'';
      setCursor = "%";
    };
    gca = "git commit --amend";

    # ブランチ操作。checkout ではなく switch / restore を既定にする
    # (git 2.23 以降の分割された方。checkout の曖昧さを避ける)
    gb = "git branch";
    gsw = "git switch";
    gswc = "git switch --create";

    # リモートとのやりとり。
    # --prune を既定にしているのは、消えたリモートブランチの
    # 追跡参照が残り続けると `git branch -a` が読めなくなるため。
    gf = "git fetch --prune";
    gp = "git push";
    gpl = "git pull";
    grb = "git rebase";

    # TUI。込み入った操作 (hunk 単位の add、rebase の並べ替え) はこちら
    lg = "lazygit";
  };

  # ghq の保存先
  home.sessionVariables.GHQ_ROOT = "$HOME/ghq";
}
