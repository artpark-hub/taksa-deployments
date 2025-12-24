.PHONY: init up down logs

init:
	sudo mkdir -p /datadrive/taksa/postgres

up:
	docker compose -f docker-compose.ory.yml up -d

down:
	docker compose -f docker-compose.ory.yml down

logs:
	docker compose -f docker-compose.ory.yml logs -f
