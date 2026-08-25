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

      # ─── サイドバーのエージェント行に Claude の会話タイトルを出す ───
      #
      # 既定は rows = [["state_icon","workspace","tab"], ["agent"]] で、
      # 2 行目が常に "claude" になる。同じリポジトリで複数セッションを
      # 並行させると 1 行目の workspace (= ディレクトリ名) まで同じになり、
      # サイドバーからはどのペインがどの会話なのか区別できない。
      #
      # Claude Code は会話の要約をターミナルタイトルとして送っていて、
      # herdr はそれを terminal_title (状態記号つき) と
      # terminal_title_stripped (記号を除いたもの) で保持している
      # (`herdr agent list` の JSON で確認できる)。2 行目をこれに差し替えると
      # 行そのものが会話名になる。エージェントの種別は状態記号と色で分かるので
      # "claude" の行は落としてよい。
      #
      # rows ではなく rows_by_agent で claude だけに効かせるのは、
      # ターミナルタイトルを送らないエージェントで 2 行目が空になるのを避けるため。
      ui = {
        sidebar.agents.rows_by_agent.claude = [
          [ "state_icon" "workspace" "tab" ]
          [ "terminal_title_stripped" ]
        ];
      };

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

    # ─── `herdr session attach/stop/delete <Tab>` でセッション名を補完する ───
    # 候補を作るのは下の __herdr_session_names。ここは complete の登録だけ。
    # 条件に session も要求するのは、同名サブコマンドを持つ
    # `herdr agent attach` などを巻き込まないため。
    complete -c herdr \
        -n '__fish_seen_subcommand_from session; and __fish_seen_subcommand_from attach stop delete' \
        -f -a '(__herdr_session_names)'
  '';

  # 同梱の clap 生成補完 (share/fish/vendor_completions.d/herdr.fish) は
  # サブコマンド名とオプションしか知らず、attach などの <NAME> 引数は
  # ファイル名補完に落ちる。そこで引数の候補だけをこちらで足す。
  # fish の complete は追加定義が既存と共存し、同梱補完のオートロードも
  # 妨げない (2026-08-22 に fish -c で共存を確認済み)。
  # ~/.config/fish/completions/herdr.fish として置く案は取らない。
  # 補完ファイルはコマンド名で先勝ち探索されるため、同梱補完が丸ごと隠れる。
  programs.fish.functions.__herdr_session_names = {
    description = "herdr のセッション名を補完候補として列挙する";
    body = ''
      # 説明欄 (タブの後ろ) に running / stopped を出す。attach したいのは
      # 大抵 running、delete できるのは stopped だけなので、
      # 候補を選ぶときの手掛かりになる。
      herdr session list --json 2>/dev/null \
          | jq -r '.sessions[] | "\(.name)\t\(if .running then "running" else "stopped" end)"'
    '';
  };

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
