# ─────────────────────────────────────────────────────────────
# Windows 側 ssh-agent への中継 (WSL2 専用)
#
# 鍵のパスフレーズを再起動のたびに入力したくない。WSL 内で
# ssh-agent を起こしても鍵はメモリ上にしか無く、再起動で消える。
# 一方 Windows 側の agent (1Password SSH agent / OpenSSH の
# ssh-agent サービス) は再起動をまたいで鍵を保持する。そこで
# agent は Windows 側に一本化し、WSL からは named pipe
# (//./pipe/openssh-ssh-agent) を npiperelay + socat で
# Unix ソケット ~/.ssh/agent.sock に中継して使う。
# 参考: https://dev.classmethod.jp/articles/wsl2-1password-ssh-agent/
#
# npiperelay.exe は named pipe に触るため Windows プロセスとして
# 動く必要があり、Nix (WSL 側) では管理しない。Windows 側
# ~/bin への配置と agent の準備 (初回のみ) は
# docs/setup/wsl2.md 7-4 章を参照。ここで管理するのは WSL 側の
# 中継 (socat) と fish への統合だけ。
#
# 記事は .bashrc からの遅延起動だが、この環境は systemd が
# 有効 (wsl2.md 3 章) なので user service で常駐させる。
# 二重起動防止や再起動をシェル側で面倒みなくてよい。
#
# fish 側の統合は home/herdr.nix の固定パス機構
# (~/.ssh/ssh_auth_sock) と組み合わさる:
#   1. ここ (mkBefore で先に実行) が生きた agent の無いシェルの
#      SSH_AUTH_SOCK を中継ソケットに向ける
#   2. herdr.nix 側がそれを固定パスに symlink し、herdr 内の
#      ペインにも届く
# SSH 転送された agent が生きていればそちらを優先するので、
# リモートから入ったときの挙動は変えない。
# ─────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

let
  cfg = config.wsl.windowsUsername;
  sock = "${config.home.homeDirectory}/.ssh/agent.sock";
  npiperelay = "/mnt/c/Users/${toString cfg}/bin/npiperelay.exe";
in
{
  options.wsl.windowsUsername = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Windows 側のユーザー名 (C:\Users\<name>)。flake.nix の userInfo から
      hosts/*.nix 経由で渡す。null なら中継ごと無効になるので、
      WSL 以外 (Docker など) で同じ home 設定を使うホストは未設定でよい。
    '';
  };

  config = lib.mkIf (cfg != null) {
    systemd.user.services.wsl-ssh-agent-relay = {
      Unit = {
        Description = "Windows ssh-agent named pipe を WSL の Unix ソケットへ中継";
        # npiperelay 未配置の環境ではサービスを黙ってスキップする
        ConditionPathExists = npiperelay;
      };
      Service = {
        # unlink-early: 前回の残骸ソケットがあると LISTEN に失敗するため。
        # fork: 複数ターミナルからの同時接続に対応するため。
        ExecStart = ''${pkgs.socat}/bin/socat UNIX-LISTEN:${sock},fork,unlink-early,mode=600 EXEC:"${npiperelay} -ei -s //./pipe/openssh-ssh-agent",nofork'';
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # herdr.nix の symlink 更新ロジックより先に走らせたいので mkBefore。
    # (後に走ると、中継ソケットが固定パスに反映されない)
    programs.fish.interactiveShellInit = lib.mkBefore ''
      # 生きた agent (SSH 転送など) が無ければ Windows agent の中継を使う
      if not test -S "$SSH_AUTH_SOCK"; and test -S ${sock}
          set -gx SSH_AUTH_SOCK ${sock}
      end
    '';
  };
}
