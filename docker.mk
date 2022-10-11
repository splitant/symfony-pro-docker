include .env

default: help

COMPOSER_ROOT ?= /var/www/html
SYMFONY_ROOT ?= /var/www/html/web
DESKTOP_PATH ?= ~/Desktop/
DOCKER_PHP_ID := $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}")

ifneq ($(SYMFONY_VERSION),)
SYMFONY_VERSION := --version=$(SYMFONY_VERSION)
endif

ifeq ($(SYMFONY_API),)
SYMFONY_API := --webapp
endif

## help	:	Print commands help.
.PHONY: help
ifneq (,$(wildcard docker.mk))
help : docker.mk
	@sed -n 's/^##//p' $<
else
help : Makefile
	@sed -n 's/^##//p' $<
endif

## up	:	Start up containers.
.PHONY: up
up:
	@echo "Starting up containers for $(PROJECT_NAME)..."
	docker-compose pull
	docker-compose up -d --remove-orphans

.PHONY: mutagen
mutagen:
	mutagen-compose up

## down	:	Stop containers.
.PHONY: down
down: stop

## start	:	Start containers without updating.
.PHONY: start
start:
	@echo "Starting containers for $(PROJECT_NAME) from where you left off..."
	@docker-compose start

## stop	:	Stop containers.
.PHONY: stop
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	@docker-compose stop

## prune	:	Remove containers and their volumes.
##		You can optionally pass an argument with the service name to prune single container
##		prune mariadb	: Prune `mariadb` container and remove its volumes.
##		prune mariadb solr	: Prune `mariadb` and `solr` containers and remove their volumes.
.PHONY: prune
prune:
	@echo "Removing containers for $(PROJECT_NAME)..."
	@docker-compose down -v $(filter-out $@,$(MAKECMDGOALS))

## ps	:	List running containers.
.PHONY: ps
ps:
	@docker ps --filter name='$(PROJECT_NAME)*'

## shell	:	Access `php` container via shell.
##		You can optionally pass an argument with a service name to open a shell on the specified container
.PHONY: shell
shell:
	docker exec -ti -e COLUMNS=$(shell tput cols) -e LINES=$(shell tput lines) $(shell docker ps --filter name='$(PROJECT_NAME)_$(or $(filter-out $@,$(MAKECMDGOALS)), 'php')' --format "{{ .ID }}") sh

## composer	:	Executes `composer` command in a specified `COMPOSER_ROOT` directory (default is `/var/www/html`).
##		To use "--flag" arguments include them in quotation marks.
##		For example: make composer "update drupal/core --with-dependencies"
.PHONY: composer
composer:
	docker exec $(DOCKER_PHP_ID) composer --working-dir=$(COMPOSER_ROOT) $(filter-out $@,$(MAKECMDGOALS))

## logs	:	View containers logs.
##		You can optinally pass an argument with the service name to limit logs
##		logs php	: View `php` container logs.
##		logs nginx php	: View `nginx` and `php` containers logs.
.PHONY: logs
logs:
	@docker-compose logs -f $(filter-out $@,$(MAKECMDGOALS))

.PHONY: create-setup
create-setup:
##		For example: make create-setup "<project_name> <repo-git>"
	cp -R ${DESKTOP_PATH}symfony-pro-docker ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker
	git clone $(word 3, $(MAKECMDGOALS)) ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker/project

.PHONY: setup
setup:
	$(MAKE) vendor
	$(MAKE) copy-pre-commit
	$(MAKE) drupal-install
	$(MAKE) packages
	$(MAKE) build

.PHONY: create-init
create-init:
##		For example: make create-init "<project_name>"
	cp -R ${DESKTOP_PATH}symfony-pro-docker ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker
	mkdir ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker/project

.PHONY: init
init:
	$(MAKE) download-symfony
	$(MAKE) create-project

.PHONY: download-symfony
download-symfony:
	docker exec -i $(DOCKER_PHP_ID) curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | docker exec -i -u root $(DOCKER_PHP_ID) bash
	docker exec -u root $(DOCKER_PHP_ID) sudo apk add symfony-cli

.PHONY: create-project
create-project:
	docker exec $(DOCKER_PHP_ID) symfony new $(SYMFONY_VERSION) $(SYMFONY_API) ./
# Find a better solution (chown -R wodby:www-data web/sites/default/files ?)
#	docker exec $(DOCKER_PHP_ID) chmod -R 777 web/sites/default/files

.PHONY: vendor
vendor:
	docker exec $(DOCKER_PHP_ID) composer --working-dir=$(COMPOSER_ROOT) install --no-interaction
	
.PHONY: gitlab-auth
gitlab-auth:
	docker exec $(DOCKER_PHP_ID) composer --working-dir=$(COMPOSER_ROOT) config --auth gitlab-token.gitlab.choosit.com ${GITLAB_TOKEN} --no-ansi --no-interaction

.PHONY: copy-env-file
copy-env-file:
	cp .env.dist .env

.PHONY: copy-pre-commit
copy-pre-commit:
	cp docker_utils/pre-commit ./project/.git/hooks/pre-commit

.PHONY: restore-dump
restore-dump:
	docker exec $(DOCKER_PHP_ID) php bin/console doctrine:database:drop --force
	docker exec $(DOCKER_PHP_ID) php bin/console doctrine:database:create
	docker exec -i $(DOCKER_PHP_ID) gunzip -c $(filter-out $@,$(MAKECMDGOALS)) | docker exec -i $(DOCKER_PHP_ID) php bin/console doctrine:database:import

# https://stackoverflow.com/a/6273809/1826109
%:
	@:
