# gwq: git worktree を ghq と同じ流儀で管理する
#
# ghq が clone を <root>/<host>/<owner>/<repo> に並べるのに対し、
# gwq は worktree を <basedir>/<naming.template> に並べる。
# 両方の root を ~/ghq に揃えることで、`dev` (home/cli/ghq.nix) 一発で
# 「本体」にも「worktree」にも飛べる状態を作る (集約派)。
#
#   ~/ghq/github.com/Zeni-Y/dotfiles-nix              ← 本体 (ghq get)
#   ~/ghq/github.com/Zeni-Y/dotfiles-nix=feature-x    ← worktree (gwq add)
#
# 詳細と、隔離派 (herdr / Claude Code の既定) との使い分けは
# docs/git/git-worktree.md を参照。
{ pkgs, ... }:

let
  # 設定本体。下の fish 連携スクリプトを生成するときにも同じものを
  # 読ませたいのでファイルとして切り出している。
  # 両者で cd.launch_shell がズレると「gwq はサブシェルを起こすのに
  # シェル側は shim で待ち受ける」という噛み合わない状態になるため、
  # 一箇所から配るのが要点。
  configFile = pkgs.writeText "gwq-config.toml" ''
    [naming]
    # 既定は '...{{.Repository}}/{{.Branch}}' で末尾が "/" のため、
    # basedir を ~/ghq にすると本体ディレクトリの「中」に worktree が生える。
    # "=" に変えて本体の「隣」に並べるのが要点。
    # sanitize_chars の既定により、ブランチ名の "/" は "-" に潰される
    # (feature/deep/x → <repo>=feature-deep-x)。ディレクトリは入れ子にならない。
    template = '{{.Host}}/{{.Owner}}/{{.Repository}}={{.Branch}}'

    [worktree]
    # ghq と同じ root。GHQ_ROOT は home/cli/ghq.nix で ~/ghq に設定している。
    basedir = '~/ghq'

    [cd]
    # false にすると `gwq cd` が「新しいシェルを起こしてその中で移動する」
    # のをやめ、選んだパスを標準出力に吐くだけになる。それを受けて
    # 現在のシェルを動かすのが下の fishIntegration。
    # true (既定) のままだと worktree を渡り歩くたびにシェルが積み上がり、
    # 戻るのに exit を数えることになる。
    launch_shell = false

    # `gwq add` した直後にその worktree へ移動する。
    # 作ってから「で、どこに出来たんだっけ」と探す手間が無くなる。
    # 元の場所に戻りたいときは `cd -`。
    auto_cd_on_add = true
  '';

  # `gwq completion fish` は補完だけでなく「シェル統合」の関数も吐く。
  # ただし後者が出るのは cd.launch_shell = false のときだけで、
  # 判定は実行時の ~/.config/gwq/config.toml を見て行われる。
  # nixpkgs の gwq が同梱する補完 (share/fish/vendor_completions.d/gwq.fish)
  # は既定値でビルドされていて統合部分を含まないので、ここで配布する
  # config.toml を読ませた状態で生成し直す。
  #
  # 補完定義は vendor 側と二重に登録されることになるが、fish は同一の
  # 候補をまとめるので実害は無い (`complete -C 'gwq '` で確認済み)。
  fishIntegration = pkgs.runCommand "gwq-fish-integration.fish" { } ''
    export HOME="$PWD"
    install -Dm644 ${configFile} "$HOME/.config/gwq/config.toml"
    ${pkgs.gwq}/bin/gwq completion fish > "$out"
  '';
in
{
  home.packages = [ pkgs.gwq ];

  # 注意: gwq 0.1.1 は XDG_CONFIG_HOME を見ず ~/.config/gwq/config.toml を
  # 直接読む。XDG_CONFIG_HOME を既定から動かしていない限り xdg.configFile の
  # 出力先と一致するので問題ないが、反映確認は `gwq config list` で行うこと。
  xdg.configFile."gwq/config.toml" = {
    # gwq は --help 以外のほぼ全サブコマンド (version でさえ) の初回実行時に
    # ~/.config/gwq/config.toml を既定値で自動生成する。Nix で配る前に一度でも
    # gwq を実行していると (`nix run nixpkgs#gwq` で試した、他経路で入っていた等)、
    # その実ファイルが残っていて activation が
    #   Existing file '~/.config/gwq/config.toml' would be clobbered
    # で止まり、switch 全体が失敗する。
    #
    # このファイルは全項目をここで宣言しているので手元で編集する意味が無い。
    # よって問答無用で上書きさせる。`-b backup` でも回避はできるが、あちらは
    # .backup が既にあると再実行がまた止まる (README「-b backup の挙動」参照)
    # ため、恒久対策には向かない。詳細は docs/nix/nix-concepts.md 7-7 章。
    force = true;

    source = configFile;
  };

  # 統合スクリプトは対話シェルでだけ読む。
  # conf.d に置くと非対話 fish (スクリプト) でも `gwq` 関数が定義され、
  # `gwq add` の標準出力が変わって噛み合わなくなる余地がある。
  # store のパスを source するだけなので、シェル起動ごとに gwq を
  # 起動する (≒ 20ms) のとは違い実行時コストは掛からない。
  programs.fish.interactiveShellInit = ''
    source ${fishIntegration}
  '';
}
