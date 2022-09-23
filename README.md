# Symfony pro docker

## About The Project

The goal is to set up fastly a local Symfony project with docker environment for professional uses.

### Built With

* [PHP](https://github.com/wodby/php)

## Getting Started

### New project

   ```sh
   make create-init <project>
   cd ../<project>-docker
   make copy-env-file
   # Fill env file
   # optionally fill GITLAB_TOKEN in .env and `make gitlab-auth`
   make up
   make init
   ```

### Installation

   ```sh
   make create-setup <project> <repo-git>
   cd ../<project>-docker
   make copy-env-file
   # Fill env file
   # optionally fill GITLAB_TOKEN in .env and `make gitlab-auth`
   make up
   make setup
   ```
