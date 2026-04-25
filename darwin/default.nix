# nix-darwin モジュールの集約
{ ... }:

{
  imports = [
    ./system.nix
    ./homebrew.nix
  ];
}
