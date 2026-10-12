# ─────────────────────────────────────────────────────────────
# macOS 固有の差分
#
# hosts/macbook.nix からだけ import する。home/default.nix に入れて
# isDarwin で分岐させないのは、Linux 側の評価にこのファイルの中身を
# 一切関わらせないため (Linux ホストの挙動が macOS 対応で変わらない)。
#
# 管理範囲は Linux と同じく ~/ 配下だけ。Homebrew・/etc/shells・
# macOS の defaults には触らない。
# ─────────────────────────────────────────────────────────────
{ lib, pkgs, ... }:

{
  # ─── ログインシェル (zsh) から fish に乗り換える ───
  #
  # macOS のログインシェルは /bin/zsh。Linux で bash から fish に exec している
  # (home/shell/bash.nix) のと同じことを zsh でやる。chsh で fish にしない理由も
  # 同じで、Nix store の fish を /etc/shells に登録する (システム領域を触る)
  # 必要が出るのと、fish を壊したときに素の zsh へ戻れなくなるため。
  #
  programs.zsh = {
    enable = true;

    # Home Manager は session 変数の読み込みのために ~/.zprofile も生成するので、
    # 手元の .zprofile にあった Homebrew の初期化はここに移す (初回 switch で
    # .zprofile.backup に退避されて消えた)。macOS は zsh をログインシェルとして
    # 起動するので .zprofile → .zshrc の順に読まれ、Homebrew の PATH は
    # exec した fish にそのまま引き継がれる。Homebrew 自体は管理しない。
    profileExtra = ''
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv zsh)"
      fi
    '';

    # exec で fish に置き換わるので compinit は無駄に時間を食うだけ
    enableCompletion = false;

    # mkOrder 1500 = 末尾。direnv / zoxide などの zsh 統合より後に置かないと、
    # exec した瞬間にそれらが読まれずに終わる (害は無いが無駄)。
    # 非対話 (zsh -c, スクリプト) では乗り換えない。
    initContent = lib.mkOrder 1500 ''
      if [[ -o interactive ]] && [[ -x ${pkgs.fish}/bin/fish ]]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };

  # 手元の ~/.zshrc に書いてあった PATH の追加をここに移す
  # (programs.zsh を有効にすると ~/.zshrc は Home Manager の生成物になる)。
  # home.sessionPath は hm-session-vars 経由で zsh にも fish にも届く。
  #   ~/.local/bin  … Claude Code のネイティブインストーラの置き場など
  #   ~/.unity/bin  … Unity Hub の CLI
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.unity/bin"
  ];

  # ─── フォント ───
  #
  # WezTerm (home/wezterm.nix) が FiraCode Nerd Font / Hack Nerd Font を指定している。
  # Ubuntu では手元 (Windows / WSL の外) の端末が描画するので Nix で入れていないが、
  # macOS ではこのマシンの WezTerm が描画するので要る。
  # Home Manager は home.packages の share/fonts を ~/Library/Fonts/HomeManager に
  # コピーする (macOS は symlink のフォントを認識しないため。targets/darwin/fonts.nix)。
  home.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  # WezTerm.app などの GUI アプリは ~/Applications/Home Manager Apps に置かれる。
  # stateVersion 25.11 以降は symlink ではなくコピー (copyApps) が既定になり、
  # Spotlight / Launchpad から起動できる。hosts/macbook.nix の stateVersion で決まる。
}
