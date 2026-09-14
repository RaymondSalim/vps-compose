.PHONY: up update build down restart logs ps shell login-codex login-opencode login-gh

up:
	docker compose up -d --build

update:
	docker compose build --pull
	docker compose up -d

build:
	docker compose build

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

shell:
	docker exec -it --user paseo paseo bash

login-codex:
	docker exec -it --user paseo paseo codex

login-opencode:
	docker exec -it --user paseo paseo opencode

login-gh:
	docker exec -it --user paseo paseo gh auth login
