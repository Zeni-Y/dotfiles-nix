# ─────────────────────────────────────────────────────────────
# 1Password CLI (op) — 秘密情報の入口
#
# API キーやトークンを .env に平文で置くのをやめ、実体は 1Password に
# 置いたまま「参照 (op://Vault/Item/field)」だけをリポジトリに持つ。
# 参照を実際の値に変えるのは direnv 側 (home/cli/direnv.nix の use_op)。
#
# op の実体は 2 通りある。既定は Linux 版:
#
#   1. Linux 版 (既定)          … nixpkgs の _1password-cli。
#      `op account add` → `op signin` でサインインする。デスクトップ
#      アプリ連携が使えないためマスターパスワードを都度入力するが、
#      リモートの Ubuntu や Docker でも同じ構成がそのまま動く。
#   2. Windows 版への中継 (WSL)  … useWindowsCli = true。WSL から
#      Windows 側の op.exe を呼ぶ薄いラッパを `op` として置く。
#      デスクトップアプリ連携が効くので Windows Hello で解錠でき、
#      direnv から非対話で叩いてもダイアログが出る。ただし Windows 側に
#      `winget install 1password-cli` と 設定 > 開発者 の CLI 連携が要る。
#
# 手順とハマりどころは docs/secrets/1password-direnv.md。
# ─────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.onepassword;

  # WSL から Windows 側 op.exe へ丸投げするラッパ。
  # op.exe は Windows プロセスなので `op run -- <Linux コマンド>` は使えない
  # (子プロセスが Windows 側で起動する)。値を stdout に出すだけの
  # `op read` / `op inject` を使う前提。
  windowsOp = pkgs.writeShellScriptBin "op" ''
    # PATH に op.exe があればそれを使う (WSL の interop で Windows の PATH が
    # 引き継がれている場合)。無ければ既定の導入先を順に見る。
    opexe="$(command -v op.exe 2>/dev/null || true)"
    candidates=(
    ${lib.optionalString (config.wsl.windowsUsername != null) ''
      "/mnt/c/Users/${config.wsl.windowsUsername}/AppData/Local/Microsoft/WinGet/Links/op.exe"
    ''}  "/mnt/c/Program Files/1Password CLI/op.exe"
    )
    if [ -z "$opexe" ]; then
      for candidate in "''${candidates[@]}"; do
        if [ -x "$candidate" ]; then
          opexe="$candidate"
          break
        fi
      done
    fi
    if [ -z "$opexe" ]; then
      echo "op: Windows 側の op.exe が見つかりません。" >&2
      echo "    Windows で 'winget install 1password-cli' を実行し、" >&2
      echo "    1Password の 設定 > 開発者 で CLI 連携を有効にしてください。" >&2
      exit 127
    fi
    exec "$opexe" "$@"
  '';
in
{
  options.programs.onepassword = {
    enable = lib.mkEnableOption "1Password CLI (op)" // { default = true; };

    useWindowsCli = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        true にすると Linux 版 op の代わりに Windows 側 op.exe へ中継する
        ラッパを入れる (WSL 専用)。デスクトップアプリ連携で Windows Hello
        が使える代わりに、Windows 側の CLI 導入が前提になる。
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Linux 版は fish / bash / zsh の補完も同梱している
    # (share/fish/vendor_completions.d/op.fish)。
    # ラッパ側に補完は付かない (Linux 版パッケージを別途引くのは重いため)。
    home.packages = [ (if cfg.useWindowsCli then windowsOp else pkgs._1password-cli) ];

    programs.fish.shellAbbrs = {
      # サインイン。op は $SHELL を見て fish 用の set コマンドを吐くので
      # eval ではなく source で読み込む (Windows 版中継のときは不要)。
      opsi = "op signin | source";
      opw = "op whoami";

      # .env.op (KEY=op://... の一覧) をその場限りの環境変数として
      # 子プロセスに渡す。direnv を使わず 1 コマンドだけ動かしたいとき用。
      opr = "op run --env-file=.env.op --";
    };
  };
}
