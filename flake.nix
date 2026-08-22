{
  description = "Zeni-Y dotfiles managed by Nix (Linux / Ubuntu)";

  # ─────────────────────────────────────────────────────────────
  # 入力 (依存パッケージのソース)
  # ─────────────────────────────────────────────────────────────
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code の公式プリビルドバイナリを提供するオーバーレイ。
    # nixpkgs に `claude-code` / `claude-code-minimal` を追加する。
    nix-claude-code = {
      url = "github:ryoppippi/nix-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ─────────────────────────────────────────────────────────────
  # 出力 (このリポジトリが提供する設定)
  #   - homeConfigurations.* : standalone Home Manager の適用対象
  #
  # 対象は Linux (Ubuntu / Docker コンテナ内含む) のみ。
  # macOS (nix-darwin) と nix-portable は対象外。
  # ─────────────────────────────────────────────────────────────
  outputs = inputs @ { self, nixpkgs, home-manager, nix-claude-code, ... }:
    let
      # 個人情報。新しいマシンを足すときはここから上書きするだけで済む。
      userInfo = {
        username = "zenimoto";
        gitName = "zenimoto";
        gitEmail = "you@example.com";  # ← 実際のメールアドレスに変更
        # WSL の中継 (home/wsl-ssh-agent.nix) が参照する C:\Users\<name>。
        # WSL 以外のホストでは使わないので null のままでよい。
        windowsUsername = "zeki1";
      };
    in
    {
      # ─── Ubuntu / Linux (standalone home-manager) ───
      # 適用コマンド:
      #   nix run home-manager/master -- switch --flake .#zenimoto@ubuntu
      homeConfigurations."${userInfo.username}@ubuntu" = import ./hosts/ubuntu.nix {
        inherit inputs userInfo;
      };
    };
}
