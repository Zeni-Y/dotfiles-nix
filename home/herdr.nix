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
    };
  };
}
