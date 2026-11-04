# ─────────────────────────────────────────────────────────────
# LibreOffice + 日本語フォント: pptx / docx をヘッドレスで PDF や画像にする
#
# 用途は「エージェントが作った pptx の見た目を、サーバー上で確かめる」こと。
#   soffice --headless --convert-to pdf slides.pptx
#   pdftoppm -png -r 80 slides.pdf page
# GUI で編集する前提ではないので、設定は持たない。
#
# 日本語フォントが無いと、変換結果の和文がすべて豆腐 (□) になる。
# Ubuntu 側のフォント (apt の fonts-noto-cjk) に頼らず Nix で入れ、
# fonts.fontconfig.enable で Home Manager のプロファイルのフォントを
# fontconfig に見せる。
#
# Linux だけで入れる。macOS では PowerPoint / Keynote で直接開けばよく、
# nixpkgs の libreoffice も darwin ではビルドできないため。
# ─────────────────────────────────────────────────────────────
{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = with pkgs; [
    libreoffice
    noto-fonts-cjk-sans   # 和文の既定のフォールバック
    biz-ud-gothic         # BIZ UDPGothic。下の置き換え先
  ];

  fonts.fontconfig.enable = true;

  # Windows で作ったスライドが指定している和文フォントは、ここには無い
  # (モリサワの石井ゴシックは商用、メイリオ / 游ゴシックは Windows 同梱)。
  # 何も書かないと fontconfig が適当なフォントに落とし、字幅が変わって
  # 折り返しやはみ出しの位置が実物とずれるので、字形と字幅が近い
  # BIZ UDPGothic (プロポーショナル) に寄せる。完全には一致しないので、
  # 最終確認は Windows の PowerPoint で行う。
  xdg.configFile."fontconfig/conf.d/60-office-jp-substitutes.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
    ${lib.concatMapStrings (family: ''
      <alias binding="same">
        <family>${family}</family>
        <prefer><family>BIZ UDPGothic</family></prefer>
      </alias>
    '') [
      "A P-SK 石井ゴシック StdN M"
      "A P-SK 石井ゴシック StdN EB"
      "メイリオ"
      "Meiryo"
      "游ゴシック"
      "Yu Gothic"
    ]}
    </fontconfig>
  '';
}
