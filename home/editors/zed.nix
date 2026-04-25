# ─────────────────────────────────────────────────────────────
# Zed エディタ
#
# Zed 本体は GUI アプリのため macOS では Homebrew Cask で入れる
# (darwin/homebrew.nix を参照)。Linux では home.packages に追加してもよい。
# ここでは設定ファイル ~/.config/zed/{settings,keymap}.json を書き出す。
# ─────────────────────────────────────────────────────────────
{ pkgs, lib, config, ... }:

let
  settings = {
    base_keymap = "VSCode";
    theme = {
      mode = "dark";
      light = "One Light";
      dark = "One Dark";
    };
    icon_theme = {
      mode = "dark";
      light = "Zed (Default)";
      dark = "Zed (Default)";
    };

    ui_font_size = 16;
    buffer_font_size = 15;
    buffer_font_family = "Consolas";
    buffer_font_fallbacks = [ "Hack Nerd Font" "monospace" ];

    autosave = {
      after_delay = { milliseconds = 1000; };
    };
    ensure_final_newline_on_save = true;

    cursor_shape = "block";
    cursor_blink = true;
    current_line_highlight = "all";
    colorize_brackets = true;
    show_edit_predictions = true;

    tab_bar = { show = false; };
    minimap = { show = "never"; };
    project_panel = {
      auto_reveal_entries = false;
      auto_fold_dirs = true;
      indent_size = 6;
    };

    terminal = {
      font_family = "JetBrainsMono Nerd Font";
      line_height = "standard";
    };

    telemetry = {
      diagnostics = true;
      metrics = false;
    };

    session = { trust_all_worktrees = true; };
  };

  keymap = [
    {
      context = "Editor";
      bindings = {
        "ctrl-shift-k" = "editor::DeleteLine";
        "ctrl-shift-d" = "editor::DuplicateLineDown";
        "alt-z" = "editor::ToggleSoftWrap";
      };
    }
  ];

in
{
  # macOS は ~/.config/zed、Linux も同じパスでよい
  xdg.configFile."zed/settings.json".text = builtins.toJSON settings;
  xdg.configFile."zed/keymap.json".text = builtins.toJSON keymap;
}
