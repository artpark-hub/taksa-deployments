.PHONY: init up down start stop logs clean help

SHELL := /bin/bash

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project (create data persistence directories and env file and certs)
	sudo mkdir -p /datadrive/taksa/data/{ory-db,timescale-db,nats-data}
	cp -i taksa.env.example taksa.env
	./scripts/generate-ssl-certs.sh

up: ## Create and start the stack in detached mode
	./taksa-stack-management.sh up -d

down: ## Stop and remove the stack and volumes
	./taksa-stack-management.sh down -v

start: ## Start existing containers
	./taksa-stack-management.sh start

stop: ## Stop running containers
	./taksa-stack-management.sh stop 

logs: ## Follow container logs
	./taksa-stack-management.sh logs -f

clean: ## Remove the stack and delete data directories
	./taksa-stack-management.sh down -v
	sudo rm -rf /datadrive/taksa/data
