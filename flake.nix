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

    # macOS 上で Homebrew 自体をブートストラップする (nix-darwin の
    # `homebrew` モジュールは brew コマンドが入っている前提なので、
    # 事前インストールを自動化するためにこの input を使う)。
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  # ─────────────────────────────────────────────────────────────
  # 出力 (このリポジトリが提供する設定)
  #   - homeConfigurations.* : Ubuntu などで standalone Home Manager を使う場合
  #   - darwinConfigurations.* : macOS で nix-darwin + Home Manager を使う場合
  #   - apps.<system>.switch  : `nix run .#switch` で Home Manager を適用
  # ─────────────────────────────────────────────────────────────
  outputs = inputs @ { self, nixpkgs, home-manager, nix-darwin, nix-homebrew, ... }:
    let
      # 個人情報。新しいマシンを足すときはここから上書きするだけで済む。
      userInfo = {
        username = "zenimoto";
        gitName = "zenimoto";
        gitEmail = "you@example.com";  # ← 実際のメールアドレスに変更
      };

      linuxSystem = "x86_64-linux";
      linuxPkgs = nixpkgs.legacyPackages.${linuxSystem};
    in
    {
      # ─── Ubuntu / Linux (standalone home-manager) ───
      # 適用コマンド (初回・以降ともに):
      #   nix run .#switch
      homeConfigurations."${userInfo.username}@ubuntu" = import ./hosts/ubuntu.nix {
        inherit inputs userInfo;
      };

      # ─── macOS (nix-darwin + Home Manager) ───
      # 適用コマンド (初回・以降ともに):
      #   sudo nix run nix-darwin -- switch --flake .#${userInfo.username}
      darwinConfigurations.${userInfo.username} = import ./hosts/macos.nix {
        inherit inputs userInfo;
      };

      # ─── `nix run .#switch` 用の薄いラッパー ───
      # Linux 側で初回ブートストラップ用に home-manager を呼ぶ。
      # ユーザーは dotfiles ディレクトリで実行する想定。
      apps.${linuxSystem}.switch = {
        type = "app";
        program = toString (linuxPkgs.writeShellScript "switch" ''
          exec ${home-manager.packages.${linuxSystem}.default}/bin/home-manager \
            switch --flake .#${userInfo.username}@ubuntu "$@"
        '');
      };
    };
}
