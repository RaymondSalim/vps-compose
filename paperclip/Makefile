.PHONY: init up build update down restart logs ps shell aws-config aws-login login-codex login-opencode login-gh bootstrap doctor agent-versions backup-db

init:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		sed -i "s|^BETTER_AUTH_SECRET=.*|BETTER_AUTH_SECRET=$$(openssl rand -hex 32)|" .env; \
		sed -i "s|^PAPERCLIP_AGENT_JWT_SECRET=.*|PAPERCLIP_AGENT_JWT_SECRET=$$(openssl rand -hex 32)|" .env; \
		sed -i "s|^PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=.*|PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=$$(openssl rand -hex 32)|" .env; \
		sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$$(openssl rand -hex 32)|" .env; \
	fi
	@echo "Edit .env, then run make aws-config and make up."

aws-config:
	@mkdir -p data/.aws
	@if [ ! -f data/.aws/config ]; then cp aws-config.example data/.aws/config; fi
	@echo "Edit data/.aws/config with your SSO values."

up:
	@docker network inspect proxy >/dev/null 2>&1 || docker network create proxy
	docker compose up -d --build

build:
	docker compose build --pull

update:
	docker compose build --pull
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

shell:
	docker exec -it --user node paperclip bash

aws-login:
	docker exec -it --user node paperclip aws sso login --profile bedrock --no-browser --use-device-code

login-codex:
	docker exec -it --user node paperclip codex

login-opencode:
	docker exec -it --user node paperclip opencode auth login

login-gh:
	docker exec -it --user node paperclip gh auth login

bootstrap:
	docker exec -it --user node paperclip paperclipai auth bootstrap-ceo

doctor:
	docker exec --user node paperclip paperclipai doctor

agent-versions:
	docker exec --user node paperclip sh -c 'claude --version; codex --version; opencode --version; gemini --version; kimi --version; gh --version | head -n 1; aws --version; paperclipai --version'

backup-db:
	@mkdir -p backups
	docker compose exec -T db pg_dump -U paperclip -d paperclip > "backups/paperclip-$$(date +%Y%m%d-%H%M%S).sql"
