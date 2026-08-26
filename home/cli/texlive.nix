# ─────────────────────────────────────────────────────────────
# TeX Live: 日本語 LaTeX (platex + pbibtex + dvipdfmx) を latexmk で回す
#
# apt の texlive はディストリのリリースに引きずられて古くなる (Ubuntu 22.04
# なら TeX Live 2021) のに対し、nixpkgs の texlive は flake.lock で年を
# 固定できるので、こちらで入れる。sudo も要らない。
#
# `texlive.withPackages` は選んだパッケージだけを合成した 1 つの環境を作る。
# scheme-full は 5GB 級で、日本語 + 一般的な論文用途には要らないものが
# ほとんどなので採らない。逆に scheme-basic だけだと ulem や amsmath が
# 無いので、必要な collection を足していく形にしている。
#
# 対応する apt のパッケージ:
#   texlive-lang-japanese      → collection-langjapanese (platex / pbibtex / 和文フォント)
#   texlive-latex-extra        → collection-latexextra   (ulem など)
#   texlive-fonts-recommended  → collection-fontsrecommended
#   texlive-science            → collection-mathscience  (amsmath / amssymb)
#   latexmk                    → latexmk
#
# dvipdfmx と kanji-config-updmap (和文フォントの割り当て) は TeX Live 標準の
# 設定のまま使う。TeX Live 2020 以降は原ノ味フォント (haranoaji) が既定で
# 埋め込まれるので、ここで updmap を触る必要はない。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  texlive = pkgs.texlive.withPackages (ps: with ps; [
    scheme-basic              # tex / dvipdfmx / kpathsea など土台
    collection-latexrecommended
    collection-latexextra
    collection-fontsrecommended
    collection-mathscience
    collection-langjapanese   # platex / uplatex / pbibtex / mendex / 和文フォント
    latexmk
  ]);
in
{
  home.packages = [ texlive ];

  # latexmk の既定を「platex → dvi → dvipdfmx → pdf」に倒す。
  # latexmk の既定は pdflatex 直行なので、これを書かないと platex 前提の
  # 文書 (jsarticle など) が通らない。
  #
  # latexmk はこの ~/.latexmkrc の後にカレントディレクトリの
  # ./.latexmkrc を読むので、pdflatex や lualatex を使う文書は
  # プロジェクト側に .latexmkrc を置けば上書きできる。
  home.file.".latexmkrc".text = ''
    # -kanji=utf8 は入力の文字コードの明示。省略すると環境変数まかせになり、
    # ロケールが C の環境 (コンテナや ssh 越し) で文字化けする。
    $latex     = 'platex -kanji=utf8 -halt-on-error -interaction=nonstopmode -synctex=1 %O %S';
    $bibtex    = 'pbibtex -kanji=utf8 %O %B';
    $makeindex = 'mendex %O -o %D %S';
    $dvipdf    = 'dvipdfmx %O -o %D %S';

    # 3 = latex で dvi を作り $dvipdf で pdf にする。1 (pdflatex 直行) だと
    # dvipdfmx を通らないので和文フォントの埋め込みが効かない。
    $pdf_mode = 3;

    # 相互参照や文献の番号が収束するまで回す回数の上限。
    $max_repeat = 5;
  '';

  programs.fish.shellAbbrs = {
    # 既定 (~/.latexmkrc) が platex ルートなので -pdfdvi は付けなくてよい。
    lmk = "latexmk";
    # 中間ファイル (aux / dvi / log) を消す。-C にすると pdf まで消える。
    lmkc = "latexmk -c";
  };
}
