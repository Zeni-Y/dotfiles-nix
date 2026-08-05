# fzf: あいまい検索。bash/fish に統合
{ ... }:

{
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];

    # 黒背景で沈む要素だけ明るくする (fish 側の配色と揃える)。
    #
    # fzf は件数表示・境界線・説明文に暗いグレーを当てるため、
    # 背景が暗いとほとんど読めない。逆に候補やマッチ位置の色は
    # 端末テーマに追随して見えているので指定しない。
    #
    # bg も指定しない。WezTerm 側で window_background_opacity を
    # 0.9 にしているため、塗り潰すと fzf の範囲だけ透過が切れる。
    colors = {
      info = "#a6adc8";       # 件数表示 (1/234)
      border = "#7f849c";     # --border の枠線
      header = "#a6adc8";
      "bg+" = "#45475a";      # 選択中の行
      "fg+" = "#cdd6f4";
    };
  };
}
