# ─────────────────────────────────────────────────────────────
# herdr 設定 (https://herdr.dev/)
#
# tmux / zellij の置き換え。ターミナルを常駐サーバー側で保持するため、
# セッションの永続化・復元は herdr 自体の機能でまかなえる
# (tmux の resurrect / continuum 相当が組み込み)。
#
# 設定は home-manager の programs.herdr.settings が
# ~/.config/herdr/config.toml に TOML として書き出す。
# 全オプションは https://herdr.dev/docs/configuration/ を参照。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.herdr = {
    enable = true;

    settings = {
      # 初回起動時のオンボーディング画面をスキップする。
      # (設定は Nix 側で持つのでウィザードを通す必要がない)
      onboarding = false;

      terminal = {
        # "fish" と書くと PATH 上の fish (apt 版の /usr/bin/fish など) が
        # 使われてしまうので、Home Manager 管理の fish を絶対パスで指定する。
        default_shell = "${pkgs.fish}/bin/fish";

        # 新規ペインは元のペイン / ワークスペースの cwd を引き継ぐ。
        # tmux 側で `split-window -c "#{pane_current_path}"` にしていたのと同じ挙動。
        new_cwd = "follow";
      };

      keys = {
        # prefix は ctrl+q。
        #
        # herdr 既定の ctrl+b は fish の backward-char、tmux 時代に使っていた
        # ctrl+t は fzf のシェル統合 (fzf-file-widget) と衝突する。
        # prefix はペインより先に herdr が食うため、衝突したキーは
        # ペインの中のアプリに届かなくなる。
        #
        # ctrl+q が奪うのは次の 3 つで、いずれも代替手段がある:
        #   - fzf の abort        → ctrl+c / ctrl+g / esc
        #   - Neovim の CTRL-Q    → ノーマルモードでは未使用。挿入 / コマンドライン
        #                           モードの CTRL-V 相当 (literal 入力) だけ失う
        #   - readline の quoted-insert (bash) → CTRL-V
        # 端末のフロー制御 (XON) も ctrl+q だが、herdr クライアントは
        # raw モードで入力を読むため干渉しない。
        prefix = "ctrl+q";
      };
      # ペイン移動 (prefix+h/j/k/l) や分割は herdr の既定キーマップが
      # すでに prefix-first の vi 風になっているため上書きしない。
      # 有効なキーバインドは起動後 prefix+? で確認できる。

      # WezTerm 側 (Catppuccin Mocha) と揃える。
      theme = {
        name = "catppuccin";
      };

      # tmux の `status-position top` に相当する設定は herdr 0.7.5 には無い
      # (タブバーは常に上)。以前書いていた ui.tab_bar_position は未知キーとして
      # 無視されていたので削除した。タブバー周りで指定できるのは
      # ui.hide_tab_bar_when_single_tab など。
      # 設定を足したときは `herdr config check` で不明キーが無いか確認する。

      session = {
        # 復元時にエージェントのセッションも再開する。
        resume_agents_on_restore = true;
      };

      experimental = {
        # Kitty graphics protocol のペイン内描画 (herdr 0.7.5 では実験的機能)。
        # ペインの中のプログラムが送った画像を、アタッチ中のクライアント経由で
        # 外側のターミナルに転送して描画する。外側のターミナル側の対応も必要で、
        # WezTerm は enable_kitty_graphics = true (home/wezterm.nix) とセットで
        # 初めて表示される (2026-08-08 に赤い矩形の描画テストで確認済み)。
        kitty_graphics = true;
      };
    };
  };

  # ─── SSH agent forwarding を herdr のペインでも生かす ───
  #
  # herdr サーバは起動時の環境変数を保持し続けるため、SSH を張り直して
  # 転送ソケット (/tmp/ssh-XXXX/agent.NNN) のパスが変わっても、ペインの
  # SSH_AUTH_SOCK は消えた古いソケットを指したままになる
  # (`ssh-add -L` → `Error connecting to agent: No such file or directory`)。
  # tmux の update-environment 相当は herdr 0.7.5 に無い
  # (--default-config / docs/configuration / CLI ヘルプで確認。
  # サーバ環境を書き換える API も無いので外からも直せない)。
  #
  # そこで「サーバの env を直す」のではなく「env が指す先を固定する」:
  #   - herdr の外 (SSH 直下のシェル): 生きているソケットを固定パス
  #     ~/.ssh/ssh_auth_sock に symlink し直す
  #   - herdr の中のペイン: 常にその固定パスを見る
  # SSH を張り直すたびに外側のシェルが symlink を更新するので、
  # herdr 内の全ペインは開き直さなくても新しいソケットに届く。
  #
  # HERDR_ENV で分岐しているのは、herdr 内のシェルが継承した古い値で
  # symlink を上書きしてしまうのを防ぐため。同時に複数の SSH 接続が
  # あると最後のログインが symlink を取るが、どれも生きたソケットなので
  # 実害はない。
  programs.fish.interactiveShellInit = ''
    if set -q HERDR_ENV
        set -gx SSH_AUTH_SOCK $HOME/.ssh/ssh_auth_sock
    else if test -S "$SSH_AUTH_SOCK"; and test "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock"
        ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
    end
  '';

  # 起動・再アタッチを短く打てるようにする短縮入力。
  # `hd` も alias ではなく abbr にする。履歴とプロンプトに展開後の
  # `herdr ...` が残り、展開してからオプションを足せるため (docs/shell/fish-abbr.md 2 章)。
  # `hd` という名前のコマンドは PATH 上に存在しない (hexdump の hd は
  # bsdmainutils 由来で、この環境には入っていない) ので衝突しない。
  # bash には abbr に相当する仕組みが無いが、対話 bash は fish に exec する
  # (home/shell/bash.nix) ので bash 側には何も置かない。
  #
  # nixpkgs の herdr は clap 生成の fish 補完を同梱しているので、
  # 展開後の `herdr <Tab>` の候補出しは何もしなくても効く。
  # ここに置くのは「補完で辿るより打った方が速い」定型だけ。
  programs.fish.shellAbbrs = {
    hd = "herdr";
    hdl = "herdr session list";
    hda = "herdr session attach";

    # 設定を足したあとに不明キーが無いか確かめる。
    # docs/terminal/herdr.md でも「設定変更のたびに実行する」と書いているもの。
    hdc = "herdr config check";
  };
}
