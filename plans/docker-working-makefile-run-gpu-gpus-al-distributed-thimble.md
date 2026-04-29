# docker/working: GPU 判定の堅牢化と LAN 越し vllm 利用ガイド

## Context

`docker/working/Makefile` の `make run` には既に GPU 自動判定があるが、
`command -v nvidia-smi` でバイナリの存在のみを見るため、ドライバ不整合などで
`nvidia-smi` バイナリだけがあって実行に失敗する環境では `--gpus all` が誤って付き、
`docker run` 自体が落ちる可能性がある。

ユーザー要望:

1. GPU が利用可能なときだけ `--gpus all` を付け、なければ外す挙動を **より確実に** 実装する
2. このコンテナの中から、LAN 内の別マシンの Docker コンテナで動いている vLLM server に
   リクエストを送る方法を知りたい（コード変更ではなくチャットで解説）

本計画では (1) のみを Makefile 修正として扱い、(2) は本ファイル末尾に解説として記載する
（Makefile / README には反映しない）。

## 変更内容

### 修正対象

- `docker/working/Makefile`（1 行のみ）

### 修正前 (line 20)

```makefile
GPU_FLAG := $(shell command -v nvidia-smi >/dev/null 2>&1 && echo --gpus all)
```

### 修正後

```makefile
GPU_FLAG := $(shell nvidia-smi >/dev/null 2>&1 && echo --gpus all)
```

### 差分の意味

- `command -v nvidia-smi` は **バイナリが PATH にあるか** だけのチェック
- `nvidia-smi` を直接呼ぶと、**実際に GPU クエリが成功した場合のみ** 真になる
  - GPU 非搭載 / ドライバ未ロード / nvidia-smi のクラッシュ等を全て除外できる
  - Mac（nvidia-smi 自体が無い）でも従来どおりフラグが外れる
- 19 行目のコメントの意図（"NVIDIA GPU が利用可能なときだけ"）にも忠実

## 検証

```bash
# 1. GPU マシンで確認
cd docker/working
make build
make run                 # docker ps で --gpus all が効いているか
docker inspect $USER_working_container | grep -i nvidia
make gpu-test            # nvidia-smi がコンテナで通ること
make clean

# 2. GPU 無し環境（または `sudo chmod 000 $(command -v nvidia-smi)` で擬似的に）
make run                 # エラーなく起動し、--gpus all が付かないことを確認
docker inspect $USER_working_container | grep -i nvidia   # 何も出ない想定
```

確認ポイント:

- GPU あり → コンテナ内で `nvidia-smi` が動く
- GPU なし → `make run` がエラーなく完走

---

## 補足解説: LAN 越しの vLLM server へのアクセス（コード変更なし）

### 前提となるネットワーク構成

`make run` は `--network zenimoto`（ホストローカルなカスタム bridge）でコンテナを立ち上げる。
このネットワークは **ホストマシン内** で完結するため、別マシンのコンテナとは
直接コンテナ名でつながらない。代わりに以下の経路を使う:

```
[このコンテナ] → [このホスト] → LAN → [vLLM ホスト :PORT] → [vLLM コンテナ :8000]
```

つまり、**別マシン側で vLLM コンテナのポートをホストに publish してもらう** のが基本。

### 別マシン側（vLLM server を動かす側）の準備

別マシンで `docker run` する際に `-p` でホストにポートを公開しておく:

```bash
docker run --gpus all -d \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  --ipc=host \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0       # ← 0.0.0.0 で待ち受けないと外から繋がらない
```

確認:

```bash
# vLLM ホスト上で
ss -tlnp | grep 8000        # 0.0.0.0:8000 で LISTEN しているか
ip -4 addr | grep inet       # LAN IP を控える（例: 192.168.1.42）
curl -s http://localhost:8000/v1/models
```

ファイアウォール（ufw / firewalld / Windows Defender 等）が有効なら
TCP 8000 を LAN から許可する必要がある。

### このコンテナ側からのアクセス

`--network zenimoto` でも、デフォルトの bridge ドライバなので **外向き通信は普通に通る**。
別マシンの LAN IP に対して直接アクセスすればよい:

```bash
# まず疎通確認
make shell
curl -v http://192.168.1.42:8000/v1/models
```

OpenAI 互換 API なので、Python からは `openai` SDK がそのまま使える:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://192.168.1.42:8000/v1",
    api_key="dummy",  # vLLM は --api-key 未指定なら何でも通る
)

resp = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "hello"}],
)
print(resp.choices[0].message.content)
```

### よくある詰まりどころ

| 症状                                         | 原因                            | 対処                                                                                         |
| -------------------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------- |
| `Connection refused`                         | vLLM が `127.0.0.1` で待機      | `--host 0.0.0.0` を付け直す                                                                  |
| `No route to host` / `timeout`               | ファイアウォール                | LAN から TCP 8000 を許可                                                                     |
| ホスト名で引けない                           | mDNS 未設定                     | LAN IP 直指定 or `/etc/hosts` 追記                                                           |
| LAN からは見えるがコンテナからだけ繋がらない | Docker bridge の MTU / iptables | `make run` の `--network zenimoto` を一時的に外して `--network host`（Linux のみ）で切り分け |

### （参考）DNS 名で扱いたい場合

毎回 IP を書きたくない場合は、ホスト OS 側の `/etc/hosts` に
`192.168.1.42 vllm-host` のような行を入れておけば、コンテナにマウントしている
`/home/$USER/host` 経由ではなく **コンテナの `/etc/resolv.conf` 経由** で解決される
（Docker は基本的にホストの DNS 設定を継承する）。
シェル変数として `VLLM_BASE_URL=http://vllm-host:8000/v1` を chezmoi 管理の
`~/.config/fish/conf.d/*.fish` 等に書いておくと取り回しが楽になる。

## 想定外スコープ（今回はやらないこと）

- README.md への追記（ユーザー要望はチャット解説のみ）
- `make run` への `-e VLLM_BASE_URL` 追加などの環境変数注入
- `docker network` を host や macvlan に切り替える検討
