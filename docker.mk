include .env

default: help

COMPOSER_ROOT ?= /var/www/html
SYMFONY_ROOT ?= /var/www/html/web
DESKTOP_PATH ?= ~/Desktop/

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
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) $(filter-out $@,$(MAKECMDGOALS))

## drush	:	Executes `drush` command in a specified `DRUPAL_ROOT` directory (default is `/var/www/html/web`).
##		To use "--flag" arguments include them in quotation marks.
##		For example: make drush "watchdog:show --type=cron"
.PHONY: drush
drush:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) $(filter-out $@,$(MAKECMDGOALS))

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
	cp -R ${DESKTOP_PATH}drupal-pro-docker ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker
	git clone $(word 3, $(MAKECMDGOALS)) ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker/project

.PHONY: setup
setup:
	$(MAKE) vendor
	$(MAKE) copy-files
	$(MAKE) drupal-install
	$(MAKE) packages
	$(MAKE) build

.PHONY: create-init
create-init:
##		For example: make create-init "<project_name>"
	cp -R ${DESKTOP_PATH}drupal-pro-docker ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker
	mkdir ${DESKTOP_PATH}$(word 2, $(MAKECMDGOALS))-docker/project

.PHONY: init
init:
	$(MAKE) create-project
	$(MAKE) vendor
	$(MAKE) drupal-init

.PHONY: pull
pull:
	$(MAKE) drush-cex
	$(MAKE) vendor
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) updatedb -y
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) config:import -y
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) locale:check
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) locale:update
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) cache:rebuild

.PHONY: drush-cex
drush-cex:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) config:export -y --destination=./export

.PHONY: vendor
vendor:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) install -o

.PHONY: create-project
create-project:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") rmdir front
ifeq ($(DRUPAL_VER),latest)
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) create-project drupal/recommended-project ./
else
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) create-project drupal/recommended-project:${DRUPAL_VER} ./
endif
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") mkdir front
# Find a better solution (chown -R wodby:www-data web/sites/default/files ?)
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") chmod -R 777 web/sites/default/files
	
.PHONY: gitlab-auth
gitlab-auth:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) config --auth gitlab-token.gitlab.choosit.com ${GITLAB_TOKEN} --no-ansi --no-interaction

.PHONY: copy-files
copy-files:
	$(MAKE) copy-pre-commit
	$(MAKE) copy-settings-php

.PHONY: copy-env-file
copy-env-file:
	cp .env.dist .env

.PHONY: copy-pre-commit
copy-pre-commit:
	cp docker_utils/pre-commit ./project/.git/hooks/pre-commit

.PHONY: copy-settings-php
copy-settings-php:
	cp docker_utils/default.settings.php ./project/web/sites/default/settings.php

.PHONY: drupal-install
drupal-install:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) site:install minimal -y --account-name=${INSTALL_ACCOUNT_NAME} --account-pass=${INSTALL_ACCOUNT_PASS} --account-mail=${INSTALL_ACCOUNT_MAIL} --existing-config

.PHONY: drupal-init
drupal-init:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) site:install -y --db-url=${DB_DRIVER}://root:${DB_ROOT_PASSWORD}@${DB_HOST}/${DB_NAME} --account-name=${INSTALL_ACCOUNT_NAME} --account-pass=${INSTALL_ACCOUNT_PASS} --account-mail=${INSTALL_ACCOUNT_MAIL}

.PHONY: packages
packages:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_node' --format "{{ .ID }}") npm install

.PHONY: build
build:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_node' --format "{{ .ID }}") npm run build

.PHONY: restore-dump
restore-dump:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) sql-drop -y
	docker exec -i $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") gunzip -c $(filter-out $@,$(MAKECMDGOALS)) | docker exec -i $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) sql-cli
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) uli

.PHONY: backup
backup:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_php' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) sql-dump --result-file=auto --gzip

# https://stackoverflow.com/a/6273809/1826109
%:
	@:
