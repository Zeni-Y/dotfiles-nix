{
  description = "Zeni-Y dotfiles managed by Nix (macOS + Ubuntu)";

  # ─────────────────────────────────────────────────────────────
  # 入力 (依存パッケージのソース)
  # ─────────────────────────────────────────────────────────────
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS のシステム設定 (Homebrew 連携・defaults write 等) に使う
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ─────────────────────────────────────────────────────────────
  # 出力 (このリポジトリが提供する設定)
  #   - homeConfigurations.* : Ubuntu などで standalone Home Manager を使う場合
  #   - darwinConfigurations.* : macOS で nix-darwin + Home Manager を使う場合
  # ─────────────────────────────────────────────────────────────
  outputs = inputs @ { self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      # 個人情報。新しいマシンを足すときはここから上書きするだけで済む。
      userInfo = {
        username = "zenimoto";
        gitName = "zenimoto";
        gitEmail = "you@example.com";  # ← 実際のメールアドレスに変更
      };
    in
    {
      # ─── Ubuntu / Linux (standalone home-manager) ───
      # 適用コマンド:
      #   nix run home-manager/master -- switch --flake .#zenimoto@ubuntu
      homeConfigurations."${userInfo.username}@ubuntu" = import ./hosts/ubuntu.nix {
        inherit inputs userInfo;
      };

      # ─── macOS (nix-darwin + Home Manager) ───
      # 適用コマンド:
      #   sudo darwin-rebuild switch --flake .#mac
      darwinConfigurations."mac" = import ./hosts/macos.nix {
        inherit inputs userInfo;
      };
    };
}
