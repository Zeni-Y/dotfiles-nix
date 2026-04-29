# シェル統合・設定が必要な CLI ツールたち
{ ... }:

{
  imports = [
    ./bat.nix
    ./direnv.nix
    ./fzf.nix
    ./gh.nix
    ./zoxide.nix
    ./eza.nix
    ./zellij.nix
  ];
}
