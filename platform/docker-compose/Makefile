.PHONY: init up down start stop logs

init:
	sudo mkdir -p /datadrive/taksa/ory-db
	sudo mkdir -p /datadrive/taksa/timescale-db
	cp -i taksa.env.example taksa.env

up:
	./taksa-stack-management.sh up -d

down:
	./taksa-stack-management.sh down -v

start:
	./taksa-stack-management.sh start

stop:
	./taksa-stack-management.sh stop 

logs:
	./taksa-stack-management.sh logs -f
