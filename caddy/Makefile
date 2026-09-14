.PHONY: up update down restart logs ps validate reload

up:
	docker network inspect proxy >/dev/null 2>&1 || docker network create proxy
	docker compose up -d

update:
	docker compose pull
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

validate:
	docker compose run --rm caddy caddy validate --config /etc/caddy/Caddyfile

reload:
	docker exec caddy caddy reload --config /etc/caddy/Caddyfile
