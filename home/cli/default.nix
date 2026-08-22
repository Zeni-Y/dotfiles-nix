# シェル統合・設定が必要な CLI ツールたち
{ ... }:

{
  imports = [
    ./bat.nix
    ./direnv.nix
    ./fzf.nix
    ./gh.nix
    ./ghq.nix
    ./gwq.nix
    ./hiraku.nix
    ./zoxide.nix
    ./eza.nix
  ];
}
