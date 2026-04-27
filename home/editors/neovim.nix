# ─────────────────────────────────────────────────────────────
# Neovim
#
# プラグインまでは管理せず、本体と最小限のオプションだけ入れる。
# 細かい設定は ~/.config/nvim 配下に各自で書き足す前提。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;

    withRuby = false;
    withPython3 = false;

    extraConfig = ''
      set number
      set relativenumber
      set expandtab
      set tabstop=2
      set shiftwidth=2
      set ignorecase
      set smartcase
      set termguicolors
    '';
  };
}
