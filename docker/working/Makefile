# Docker 開発環境の管理
#
# 使い方:
#   make build       - イメージをビルド
#   make run         - コンテナを起動（SSH ポート: 2222）
#   make run SSH_PORT=3333  - SSH ポートを指定して起動
#   make gpu-test    - GPU 動作確認
#   make clean       - コンテナとイメージを削除
#   make restart     - コンテナを再起動

IMAGE_NAME := $(USER)_working_image
CONTAINER_NAME := $(USER)_working_container
SSH_PORT := 2222

.PHONY: build run gpu-test clean restart stop rm

build:
	docker build \
		--build-arg USERNAME="$(USER)" \
		--build-arg USER_UID="$$(id -u)" \
		--build-arg USER_GID="$$(id -g)" \
		./ -t "$(IMAGE_NAME)"

run:
	docker network inspect zenimoto >/dev/null 2>&1 || docker network create zenimoto
	docker run --gpus all -it --name "$(CONTAINER_NAME)" \
		--network zenimoto \
		--ipc=host \
		--shm-size 16G \
		-v "$(HOME):/home/$(USER)/host" \
		-v "$(HOME)/.cache:/home/$(USER)/.cache" \
		-w "/home/$(USER)" \
		-p "$(SSH_PORT):22" \
		"$(IMAGE_NAME)"

gpu-test:
	docker run --gpus all --rm ubuntu:22.04 nvidia-smi

stop:
	docker stop "$(CONTAINER_NAME)"

rm:
	docker rm "$(CONTAINER_NAME)"

clean: stop rm
	docker rmi "$(IMAGE_NAME)"

restart: stop
	docker start -ai "$(CONTAINER_NAME)"
