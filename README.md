# Symfony pro docker

## About The Project

The goal is to set up fastly a local Symfony project with docker environment for professional uses.

### Built With

* [Official Nginx Docker Image](https://hub.docker.com/_/nginx)
* [Official PHP-FPM Docker Image](https://hub.docker.com/_/php)
* [Official MySQL Docker Image](https://hub.docker.com/_/mysql)
* [Official phpMyAdmin Docker Image](https://hub.docker.com/_/phpmyadmin)
* [Mailhog Docker Image](https://hub.docker.com/r/mailhog/mailhog)

### Requirements

* Install [mkcert](https://github.com/FiloSottile/mkcert)

## Getting Started

### Installation

   ```sh
   git clone git@github.com:splitant/symfony-pro-docker.git
   cd symfony-pro-docker
   make create-setup <project> <repo-git>
   # Fill env file
   make setup
   ```

### New project

   ```sh
   git clone git@github.com:splitant/symfony-pro-docker.git
   cd symfony-pro-docker
   make create-init <project>
   # Fill env file
   make init
   ```

## Make commands

### Connect to Prestashop container

  ```sh
  make shell
  ```

### Reset project

  ```sh
  make prune
  ```