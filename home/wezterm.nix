# ─────────────────────────────────────────────────────────────
# WezTerm 設定
#
# nixpkgs の wezterm を入れた上で ~/.config/wezterm/wezterm.lua を
# 配置する。元の dotfiles の Lua 設定をベースに最小化したもの。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.wezterm = {
    enable = true;

    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      -- フォント
      config.font = wezterm.font_with_fallback {
        { family = 'FiraCode Nerd Font', weight = 'Regular' },
        'Hack Nerd Font',
        'monospace',
      }
      config.font_size = 13.0

      -- 配色
      config.color_scheme = 'Catppuccin Mocha'
      config.window_background_opacity = 0.9
      config.window_decorations = 'RESIZE'

      -- タブバー
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = false
      config.hide_tab_bar_if_only_one_tab = false

      -- スクロールバック
      config.scrollback_lines = 10000

      -- リーダーキー
      config.leader = { key = 'w', mods = 'CTRL', timeout_milliseconds = 1500 }

      return config
    '';
  };
}
