include .env

default: help

COMPOSER_ROOT ?= /home/symfony/project
DESKTOP_PATH ?= ~/Desktop/
SYMFONY_CONTAINER := $(shell docker ps --filter name='^/$(PROJECT_NAME)_symfony' --format "{{ .ID }}")

ifeq ($(SYMFONY_VERSION),)
SYMFONY_VERSION := stable
endif

ifeq ($(SYMFONY_OPTIONS),)
SYMFONY_OPTIONS := --webapp
endif

## help : Print commands help.
.PHONY: help
ifneq (,$(wildcard docker.mk))
help : docker.mk
	@sed -n 's/^##//p' $<
else
help : Makefile
	@sed -n 's/^##//p' $<
endif

## up : Start up containers.
.PHONY: up
up:
	@echo "Starting up containers for $(PROJECT_NAME)..."
	mkdir -p project
	$(MAKE) generate-ssl-ca
	docker compose pull
	docker compose up -d --remove-orphans --build

## down : Stop containers.
.PHONY: down
down: stop

## start : Start containers without updating.
.PHONY: start
start:
	@echo "Starting containers for $(PROJECT_NAME) from where you left off..."
	@docker compose start

## stop : Stop containers.
.PHONY: stop
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	@docker compose stop

## prune : Remove containers and their volumes.
##		You can optionally pass an argument with the service name to prune single container
##		prune mariadb : Prune `mariadb` container and remove its volumes.
##		prune mariadb solr : Prune `mariadb` and `solr` containers and remove their volumes.
.PHONY: prune
prune:
	$(MAKE) clean-project
	@echo "Removing containers for $(PROJECT_NAME)..."
	@docker compose down -v $(filter-out $@,$(MAKECMDGOALS))

## clean-project : Remove project directory content
.PHONY: clean-project
clean-project:
	docker exec -u root -w /home/symfony $(SYMFONY_CONTAINER) bash -c 'shopt -s dotglob && rm -rf project/*'

## ps : List running containers.
.PHONY: ps
ps:
	@docker ps --filter name='$(PROJECT_NAME)*'

## logs : View containers logs.
##		You can optinally pass an argument with the service name to limit logs
##		logs php	: View `php` container logs.
##		logs nginx php	: View `nginx` and `php` containers logs.
.PHONY: logs
logs:
	@docker compose logs -f $(filter-out $@,$(MAKECMDGOALS))

## shell : Access `php` container via shell.
##		You can optionally pass an argument with a service name to open a shell on the specified container
.PHONY: shell
shell:
	docker exec -ti -e COLUMNS=$(shell tput cols) -e LINES=$(shell tput lines) $(shell docker ps --filter name='$(PROJECT_NAME)_$(or $(filter-out $@,$(MAKECMDGOALS)), 'symfony')' --format "{{ .ID }}") bash

## composer : Executes `composer` command in a specified `COMPOSER_ROOT` directory (default is `/var/www/html`).
##		To use "--flag" arguments include them in quotation marks.
##		For example: make composer "update symfony/dotenv --with-dependencies"
.PHONY: composer
composer:
	docker exec $(SYMFONY_CONTAINER) composer --working-dir=$(COMPOSER_ROOT) $(filter-out $@,$(MAKECMDGOALS))

## vendor : Install php packages.
.PHONY: vendor
vendor:
	docker exec $(SYMFONY_CONTAINER) composer --working-dir=$(COMPOSER_ROOT) install --no-interaction

.PHONY: copy-env-file
copy-env-file:
## copy-env-file	:	Creates .env file.
	cp .env.dist .env

.PHONY: generate-ssl-ca
generate-ssl-ca:
## generate-ssl-ca	:	Generates SSL certificates.
	mkdir -p .docker/nginx/certs
	mkcert -install
	mkcert -cert-file .docker/nginx/certs/$(NGINX_SYMFONY_SERVER_NAME).pem -key-file .docker/nginx/certs/$(NGINX_SYMFONY_SERVER_NAME)-key.pem $(NGINX_SYMFONY_SERVER_NAME)

.PHONY: create-dump
create-dump:
## create-dump	:	Creates gzip BDD dump.
	docker exec -i $(SYMFONY_CONTAINER) mysqldump -u"$(DB_USER)" -p"$(DB_PASSWORD)" -h"$(PROJECT_NAME)_$(DB_HOST)" "$(DB_NAME)" --single-transaction --create-options --extended-insert --complete-insert --databases --add-drop-database | docker exec -i $(SYMFONY_CONTAINER) sh -c 'gzip > dump_$(shell date +%d%m%Y-%H%M%S).sql.gz'

.PHONY: restore-dump
restore-dump:
## restore-dump	:	Creates gzip BDD dump.
##		For example: make restore-dump "<dump_filename>.sql.gz"
	docker exec -i $(SYMFONY_CONTAINER) zcat $(filter-out $@,$(MAKECMDGOALS)) | docker exec -i $(SYMFONY_CONTAINER) mysql -u"$(DB_USER)" -p"$(DB_PASSWORD)" -h"$(PROJECT_NAME)_$(DB_HOST)" "$(DB_NAME)"

## create-init : Setup local project.
##		For example: make create-init "<project_name>"
.PHONY: create-init
create-init:
	mv ${DESKTOP_PATH}symfony-pro-docker ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker
	mkdir ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker/project
	$(MAKE) copy-env-file

## create-project : Create blank Symfony project.
.PHONY: create-project
create-project:
ifneq ($(SYMFONY_OPTIONS),)
	docker exec $(SYMFONY_CONTAINER) symfony new --version=$(SYMFONY_VERSION) $(SYMFONY_OPTIONS) ./
else
	docker exec $(SYMFONY_CONTAINER) symfony new --version=$(SYMFONY_VERSION) ./
endif

## init : Create local project.
.PHONY: init
init:
	$(MAKE) up
	$(MAKE) create-project

## setup : Create local project from existing Git project.
.PHONY: setup
setup:
	$(MAKE) up
	$(MAKE) vendor
