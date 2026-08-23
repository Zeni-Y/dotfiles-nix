# ─────────────────────────────────────────────────────────────
# direnv: ディレクトリごとの環境変数
#
# nix-direnv で flake の devShell を自動で読み込むほか、
# stdlib に `use op` を足して 1Password から秘密情報を取り込む
# (home/cli/onepassword.nix と対。手順は docs/secrets/1password-direnv.md)。
# ─────────────────────────────────────────────────────────────
{ ... }:

{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;

    # ~/.config/direnv/direnvrc に置かれ、全 .envrc から呼べる関数になる。
    #
    # 秘密情報を平文の .env としてディスクに置かない、というのがこの関数の目的。
    # リポジトリに置くのは参照だけのテンプレート (.env.op):
    #
    #   # .env.op — 秘密は入っていないのでコミットしてよい
    #   OPENAI_API_KEY=op://Private/OpenAI/credential
    #   DATABASE_URL=op://Private/MyApp/database url
    #
    #   # .envrc
    #   use op
    #
    # 書式を `KEY=op://...` に揃えているのは、同じファイルを
    # `op run --env-file=.env.op -- <cmd>` にもそのまま渡せるようにするため。
    stdlib = ''
      # use op [テンプレート] — 既定は .env.op
      use_op() {
        local template="''${1:-.env.op}"

        if [[ ! -f "$template" ]]; then
          log_error "use op: $template が見つからない"
          return 1
        fi
        # テンプレートを書き換えたら direnv に再読み込みさせる
        watch_file "$template"

        if ! has op; then
          log_error "use op: op (1Password CLI) が PATH に無い"
          return 1
        fi

        local keys=() refs=() line key ref
        while IFS= read -r line || [[ -n "$line" ]]; do
          # op.exe 経由だと CRLF が混じることがある
          line="''${line%$'\r'}"
          line="''${line#"''${line%%[![:space:]]*}"}"
          [[ -z "$line" || "$line" == '#'* ]] && continue
          line="''${line#export }"
          key="''${line%%=*}"
          ref="''${line#*=}"
          # 値を引用符で囲んでいても囲まなくても受け付ける
          ref="''${ref%\"}"; ref="''${ref#\"}"
          ref="''${ref%\'}"; ref="''${ref#\'}"
          if [[ "$ref" != op://* ]]; then
            log_error "use op: op:// で始まらない行がある: $line"
            return 1
          fi
          keys+=("$key")
          refs+=("$ref")
        done < "$template"

        if [[ ''${#keys[@]} -eq 0 ]]; then
          log_error "use op: $template に KEY=op://... の行が無い"
          return 1
        fi

        # 参照 1 つにつき 1 プロセス (op read) にすると cd のたびに待たされるので、
        # 1 行 1 値のテンプレートを組んで op inject を 1 回だけ呼ぶ。
        local body="" i
        for i in "''${!refs[@]}"; do
          body+="{{ ''${refs[$i]} }}"$'\n'
        done

        local resolved
        # op のエラー (未サインインなど) はそのまま端末に出させる
        if ! resolved="$(printf '%s' "$body" | op inject)"; then
          log_error "use op: 解決できなかった。サインインしているか確認する (op signin)"
          return 1
        fi

        local values=()
        mapfile -t values <<< "''${resolved//$'\r'/}"
        if [[ ''${#values[@]} -ne ''${#keys[@]} ]]; then
          log_error "use op: 値の数が合わない (改行を含む秘密は use op では扱えない)"
          return 1
        fi

        # eval を通さずに export する。値に " や $ が入っていても壊れない
        for i in "''${!keys[@]}"; do
          export "''${keys[$i]}=''${values[$i]}"
        done
        log_status "1Password から ''${#keys[@]} 件読み込んだ ($template)"
      }
    '';
  };
}
