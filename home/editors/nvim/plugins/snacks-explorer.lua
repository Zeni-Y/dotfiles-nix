-- ~/.config/nvim/lua/plugins/snacks-explorer.lua (Nix が配る symlink)
--
-- LazyVim の既定 (snacks.explorer) はドットファイルと gitignore 済みの
-- エントリをツリーから隠す。手元では data/ images/ tweets/ .env.op .envrc
-- のように「追跡しないが日常的に開く」ものが多く、毎回 H / I を押して
-- 出し直すことになるので、最初から出す。
--
-- 元に戻したいときはツリー上で H (hidden) / I (ignored) を押せば
-- そのセッション中だけトグルできる。
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,

            -- ignored を出すと .git 配下も対象になる。中を開くことは無いのに
            -- 展開すると数千エントリを走査して watch まで張るので、ここだけ除く。
            -- node_modules は「たまに実装を読む」ので残す。
            exclude = { ".git" },
          },
        },
      },
    },
  },
}
