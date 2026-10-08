.PHONY: up update build down restart logs ps shell login-codex login-opencode login-gh skills skills-list skills-update

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

# Global agent skills (see skills/README.md).
skills:
	docker exec --user paseo paseo sh /opt/paseo-skills/install.sh

skills-list:
	docker exec --user paseo -e DISABLE_TELEMETRY=1 -e XDG_STATE_HOME=/home/paseo/.local/state paseo npx -y skills@1.7.1 list -g

skills-update:
	docker exec --user paseo -e DISABLE_TELEMETRY=1 -e XDG_STATE_HOME=/home/paseo/.local/state paseo npx -y skills@1.7.1 update -g -y
