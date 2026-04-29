# Docker 開発環境の管理
#
# 使い方:
#   make build       - イメージをビルド
#   make run         - コンテナをバックグラウンド起動（SSH ポート: 2222）
#   make run SSH_PORT=3333  - SSH ポートを指定して起動
#   make shell       - 起動中コンテナに bash で入る（exit してもコンテナは停止しない）
#   make ssh         - SSH agent forwarding 付きで SSH ログイン
#   make logs        - sshd のログを表示
#   make gpu-test    - GPU 動作確認
#   make restart     - コンテナを再起動
#   make stop / rm   - コンテナの停止 / 削除
#   make clean       - コンテナとイメージを削除

IMAGE_NAME := $(USER)_working_image
CONTAINER_NAME := $(USER)_working_container
SSH_PORT := 2222

# NVIDIA GPU が利用可能なときだけ --gpus all を付ける（Mac では自動で外れる）
GPU_FLAG := $(shell nvidia-smi >/dev/null 2>&1 && echo --gpus all)

.PHONY: build run shell ssh logs gpu-test clean restart stop rm

build:
	docker build \
		--build-arg USERNAME="$(USER)" \
		--build-arg USER_UID="$$(id -u)" \
		--build-arg USER_GID="$$(id -g)" \
		./ -t "$(IMAGE_NAME)"

run:
	docker network inspect zenimoto >/dev/null 2>&1 || docker network create zenimoto
	docker run -d --restart unless-stopped \
		$(GPU_FLAG) \
		--name "$(CONTAINER_NAME)" \
		--network zenimoto \
		--ipc=host \
		--shm-size 16G \
		-v "$(HOME):/home/$(USER)/host" \
		-v "$(HOME)/.cache:/home/$(USER)/.cache" \
		-w "/home/$(USER)" \
		-p "$(SSH_PORT):22" \
		-e GITHUB_TOKEN \
		"$(IMAGE_NAME)"

shell:
	docker exec -it -u "$(USER)" -w "/home/$(USER)" "$(CONTAINER_NAME)" bash --login

ssh:
	ssh -A -p "$(SSH_PORT)" "$(USER)@localhost"

logs:
	docker logs -f "$(CONTAINER_NAME)"

gpu-test:
	docker run --gpus all --rm ubuntu:22.04 nvidia-smi

stop:
	docker stop "$(CONTAINER_NAME)"

rm:
	docker rm "$(CONTAINER_NAME)"

clean: stop rm
	docker rmi "$(IMAGE_NAME)"

restart:
	docker restart "$(CONTAINER_NAME)"
