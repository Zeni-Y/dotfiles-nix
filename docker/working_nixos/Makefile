# Docker 開発環境の管理 (NixOS / nixos/nix ベース版)
#
# docker/working の Makefile とほぼ同じだが、
#   - ビルドコンテキストがリポジトリルート (dotfiles を焼き込むため)
#   - SSH ポートの既定が 2223 (working と同時に起動できるように)
# の 2 点が異なる。
#
# 使い方:
#   make build       - イメージをビルド（dotfiles の適用まで含む / 初回は数十分）
#   make run         - コンテナをバックグラウンド起動（SSH ポート: 2223）
#   make run SSH_PORT=3333  - SSH ポートを指定して起動
#   make build USERNAME=zenimoto
#                    - コンテナ内のユーザー名を指定（既定はホストの $USER）
#   make run -- -p 8000:8000 --env FOO=bar
#                    - `--` 以降を docker run の追加オプションとして渡す
#   make shell       - 起動中コンテナに bash で入る（exit してもコンテナは停止しない）
#   make ssh         - SSH agent forwarding 付きで SSH ログイン
#   make switch      - コンテナ内の dotfiles を再適用（home-manager switch）
#   make logs        - sshd のログを表示
#   make gpu-test    - GPU 動作確認
#   make restart     - コンテナを再起動
#   make stop / rm   - コンテナの停止 / 削除
#   make clean       - コンテナとイメージを削除

IMAGE_NAME := $(USER)_working_nixos_image
CONTAINER_NAME := $(USER)_working_nixos_container
# docker/working (2222) と衝突しないようにずらしてある
SSH_PORT := 2223
# コンテナ内のユーザー名。Home Manager の homeConfigurations は
# /home/<username> を前提にするので、flake.nix の userInfo.username と
# 揃える必要がある。既定ではホストの $USER をそのまま引き継ぐ。
USERNAME ?= $(USER)
# 適用する homeConfigurations の名前（home/ 以下の設定は OS 非依存なので
# Ubuntu 用の定義をそのまま使う）
HM_CONFIG ?= $(USERNAME)@ubuntu
# コンテナ起動時に https://github.com/$(GITHUB_USER).keys から authorized_keys を取得する
GITHUB_USER ?= Zeni-Y

# この Makefile は docker/working_nixos/ にあるので 2 階層上がリポジトリルート。
# dotfiles をイメージに焼き込むため、ビルドコンテキストはリポジトリ全体になる。
REPO_ROOT := $(CURDIR)/../..

# NVIDIA GPU が利用可能なときだけ --gpus all を付ける
GPU_FLAG := $(shell nvidia-smi >/dev/null 2>&1 && echo --gpus all)

# `make run -- <extra args>` の `--` 以降を docker run に渡せるようにする。
# make は `--` でオプション解析を終了するため、それ以降の語は MAKECMDGOALS に
# ターゲットとして並ぶ。それらを RUN_EXTRA_ARGS に集約し、末尾の catch-all
# ルール (`%:`) で "No rule to make target" を抑止する。
ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_EXTRA_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
endif

.PHONY: build run shell ssh switch logs gpu-test clean restart stop rm

build:
	docker build \
		-f "$(CURDIR)/Dockerfile" \
		--build-arg USERNAME="$(USERNAME)" \
		--build-arg USER_UID="$$(id -u)" \
		--build-arg USER_GID="$$(id -g)" \
		--build-arg GITHUB_USER="$(GITHUB_USER)" \
		--build-arg HM_CONFIG="$(HM_CONFIG)" \
		"$(REPO_ROOT)" -t "$(IMAGE_NAME)"

run:
	docker network inspect zenimoto >/dev/null 2>&1 || docker network create zenimoto
	docker run -d --restart unless-stopped \
		--init \
		$(GPU_FLAG) \
		--name "$(CONTAINER_NAME)" \
		--network zenimoto \
		--ipc=host \
		--shm-size 16G \
		-v "$(HOME):/home/$(USERNAME)/host" \
		-v "$(HOME)/.cache:/home/$(USERNAME)/.cache" \
		-v "$(HOME)/ghq:/home/$(USERNAME)/ghq" \
		-w "/home/$(USERNAME)" \
		-p "$(SSH_PORT):22" \
		-e GITHUB_TOKEN \
		-e GITHUB_USER="$(GITHUB_USER)" \
		$(RUN_EXTRA_ARGS) \
		"$(IMAGE_NAME)"

shell:
	docker exec -it -u "$(USERNAME)" -w "/home/$(USERNAME)" "$(CONTAINER_NAME)" bash --login

ssh:
	ssh -A -p "$(SSH_PORT)" "$(USERNAME)@localhost"

# イメージに焼き込んだ dotfiles を、コンテナ内のリポジトリから再適用する。
# ホストの ~/ghq に clone 済みのものを使いたいときは
#   make switch REPO=/home/$(USERNAME)/ghq/github.com/Zeni-Y/dotfiles-nix
REPO ?= /home/$(USERNAME)/dotfiles-nix
switch:
	docker exec -it -u "$(USERNAME)" -w "$(REPO)" "$(CONTAINER_NAME)" \
		bash -lc 'home-manager switch --flake ".#$(HM_CONFIG)"'

logs:
	docker logs -f "$(CONTAINER_NAME)"

gpu-test:
	docker run --init --gpus all --rm ubuntu:22.04 nvidia-smi

stop:
	docker stop "$(CONTAINER_NAME)"

rm:
	docker rm "$(CONTAINER_NAME)"

clean: stop rm
	docker rmi "$(IMAGE_NAME)"

restart:
	docker restart "$(CONTAINER_NAME)"

# `make run -- <extra args>` の追加引数をターゲットとして無視するための catch-all。
# 既知のターゲットには影響しないが、念のため `run` ゴールが指定された時のみ有効化する。
ifeq (run,$(firstword $(MAKECMDGOALS)))
%:
	@:
endif
