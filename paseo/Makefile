.PHONY: up update build down restart logs ps shell login-codex login-opencode login-gh login-aws skills skills-list skills-update
.PHONY: test-docker-setup test-docker-check test-docker-smoke

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

login-aws:
	docker exec -it --user paseo paseo aws sso login

# Global agent skills (see skills/README.md).
skills:
	docker exec --user paseo paseo sh /opt/paseo-skills/install.sh

skills-list:
	docker exec --user paseo -e DISABLE_TELEMETRY=1 -e XDG_STATE_HOME=/home/paseo/.local/state paseo npx -y skills@1.7.1 list -g

skills-update:
	docker exec --user paseo -e DISABLE_TELEMETRY=1 -e XDG_STATE_HOME=/home/paseo/.local/state paseo npx -y skills@1.7.1 update -g -y

# First-time host provisioning; separate from normal container startup.
test-docker-setup:
	sudo bash scripts/setup-test-docker.sh

# Check as the same non-root user that runs agent commands.
test-docker-check:
	docker exec --user paseo paseo sh -ec 'docker info --format "{{json .SecurityOptions}}" | grep -q "name=rootless"; test "$$(docker info --format "{{.DockerRootDir}}")" = /home/agent-tests/.local/share/docker; test "$$(docker info --format "{{.CgroupVersion}}")" = 2; test "$$(docker info --format "{{.CgroupDriver}}")" = systemd; docker compose version; docker info --format "Root={{.DockerRootDir}} Security={{json .SecurityOptions}}"'

test-docker-smoke: test-docker-check
	docker exec --user paseo paseo paseo-test /opt/paseo-tests/compose.smoke.yml
