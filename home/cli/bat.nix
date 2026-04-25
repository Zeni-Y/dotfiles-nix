# bat: シンタックスハイライト付き cat
{ ... }:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      style = "numbers,changes,header";
    };
  };
}
