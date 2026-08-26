# 日本語 LaTeX (platex + latexmk)

`home/cli/texlive.nix` が入れている TeX Live 環境の中身と、`latexmk` で
日本語文書 (jsarticle など) をビルドするまでの話です。

## 1. なぜ Nix で入れるか

apt の `texlive-*` はディストリのリリースに紐づくので古くなります
(Ubuntu 22.04 なら TeX Live 2021)。`sudo` も要ります。

nixpkgs の texlive はバージョンが `flake.lock` に固定されるので、
**マシンを増やしても同じ年の TeX Live が入る**のと、`sudo` なしで
`home-manager switch` だけで揃うのが利点です。更新は `nix flake update`。

## 2. 何が入るか

`pkgs.texlive.withPackages` で必要な collection だけを合成しています。
`scheme-full` (5GB 級) は採っていません。

| 入れている TeX Live パッケージ | 対応する apt のパッケージ | 主な中身 |
| --- | --- | --- |
| `scheme-basic` | (土台) | `tex` / `dvipdfmx` / `kpathsea` |
| `collection-langjapanese` | `texlive-lang-japanese` | `platex` / `uplatex` / `pbibtex` / `mendex` / 和文フォント |
| `collection-latexrecommended` | `texlive-latex-recommended` | `geometry` / `booktabs` など |
| `collection-latexextra` | `texlive-latex-extra` | `ulem` など |
| `collection-fontsrecommended` | `texlive-fonts-recommended` | 推奨フォント一式 |
| `collection-mathscience` | `texlive-science` | `amsmath` / `amssymb` |
| `latexmk` | `latexmk` | ビルド自動化 |

入っているか確かめる:

```fish
which platex pbibtex dvipdfmx latexmk
platex --version
```

和文フォントは TeX Live 2020 以降の既定 (原ノ味フォント) をそのまま使います。
`kanji-config-updmap` を叩く必要はありません。

## 3. latexmk の既定 — `~/.latexmkrc`

latexmk の素の既定は **pdflatex 直行**なので、そのままでは platex 前提の
文書が通りません。`home/cli/texlive.nix` から `~/.latexmkrc` を配って、
**platex → dvi → dvipdfmx → pdf** のルートに倒しています。

| 変数 | 値 | 意味 |
| --- | --- | --- |
| `$latex` | `platex -kanji=utf8 …` | 本文の組版 |
| `$bibtex` | `pbibtex -kanji=utf8 %O %B` | 文献 (`\bibliography`) |
| `$makeindex` | `mendex %O -o %D %S` | 索引 |
| `$dvipdf` | `dvipdfmx %O -o %D %S` | dvi → pdf |
| `$pdf_mode` | `3` | 「latex で dvi を作って `$dvipdf` で pdf にする」モード |
| `$max_repeat` | `5` | 相互参照が収束するまで回す上限 |

`-kanji=utf8` を明示しているのは、省略すると環境変数まかせになり、
ロケールが `C` の環境 (コンテナや ssh 越し) で文字化けするためです。

## 4. 使い方

```fish
latexmk main.tex          # 変更のあった段だけ回して main.pdf まで作る (abbr: lmk)
latexmk -pvc main.tex     # ファイルを監視して保存のたびに作り直す
latexmk -c                # 中間ファイル (aux / dvi / log) を消す (abbr: lmkc)
latexmk -C                # pdf も含めて消す
```

`\cite` を足したときも `pbibtex` → `platex` の追い回しは latexmk が
判断してやるので、手で順番を打つ必要はありません。

できた PDF をリモート越しに見るなら [hiraku](./hiraku.md) が使えます。

```fish
hiraku main.pdf
```

## 5. uplatex / pdflatex / lualatex の文書を混ぜたいとき

latexmk は `~/.latexmkrc` を読んだあと**カレントディレクトリの
`.latexmkrc` を読む**ので、プロジェクト側に置けば上書きできます。
例えば lualatex を使う文書なら:

```perl
# <project>/.latexmkrc
$latex = 'lualatex -halt-on-error -interaction=nonstopmode %O %S';
$pdf_mode = 1;   # pdf を直接吐くモード
```

`$pdf_mode` を 1 に戻すのを忘れると、dvi を作らない処理系なのに
dvipdfmx を通そうとして落ちます。

Unicode 版の `uplatex` (クラスオプションに `uplatex` を付ける文書) なら
`$pdf_mode` はそのまま 3 で、`$latex` と `$bibtex` だけ差し替えます。

```perl
$latex  = 'uplatex -halt-on-error -interaction=nonstopmode -synctex=1 %O %S';
$bibtex = 'upbibtex %O %B';
```

## 6. ハマりどころ

| 症状 | 原因 / 対処 |
| --- | --- |
| `! LaTeX Error: File 'xxx.sty' not found` | その collection が入っていない。`nix-locate` で探して `home/cli/texlive.nix` に足す |
| 和文が □ になる / 埋め込まれない | `$pdf_mode = 1` になっていて dvipdfmx を通っていない可能性。プロジェクトの `.latexmkrc` を確認する |
| 文字化けする | 入力が UTF-8 でない。`-kanji=` の値を実ファイルに合わせる |
| ビルドが途中で止まったまま返らない | `-interaction=nonstopmode` が効いていない (プロジェクト側で `$latex` を上書きしている) |
| `Latexmk: Bst file not found in search path: jplain.bst` | 無視してよい。`jplain.bst` は `pbibtex/bst/` にあり `kpsewhich -progname=pbibtex` でしか引けないため、latexmk の依存追跡が見失うだけ。pbibtex 自身は見つけている |

パッケージを足したら `home-manager switch` が要ります (適用は人間が実行)。

## 7. 確認済みの動作

`flake.lock` 時点の TeX Live は **2025** です。次を実際に通してあります。

- `jsarticle` + `amsmath` / `amssymb` / `ulem` の日本語文書が `latexmk` 1 回で pdf になる
- `\bibliography` + `jplain.bst` を `pbibtex` が処理し、日本語の著者名が `.bbl` に出る
- できた pdf に原ノ味フォント (`HaranoAjiMincho` / `HaranoAjiGothic`) が埋め込まれている
  (`pdffonts` の `emb` が `yes`)
