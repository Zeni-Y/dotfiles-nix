# ─────────────────────────────────────────────────────────────
# tmux 設定
#
# 元の dotfiles では TPM 経由で resurrect / continuum / prefix-highlight
# を入れている。Nix 側は同じプラグインを programs.tmux.plugins で扱える。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;

    prefix = "C-t";
    baseIndex = 1;
    keyMode = "vi";
    mouse = true;
    escapeTime = 10;
    terminal = "screen-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      prefix-highlight
      catppuccin

      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
        '';
      }

      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      # ペイン分割: カレントディレクトリを引き継ぐ
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # vi 風のペイン移動
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ペインリサイズ
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # 設定リロード
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      # ステータスバー位置
      set-option -g status-position top
    '';
  };
}
