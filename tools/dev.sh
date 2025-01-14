#!/bin/bash

# colors :P
red=$(tput setaf 1)
purple=$(tput setaf 5)
green=$(tput setaf 2)
bold=$(tput bold)
normal=$(tput sgr0)

HELP_TEXT="    ${bold}${green}dev.sh${normal} - Run ZOSIA docker containers for local development.
  ${bold}Usage:${normal} ./dev.sh [command] [options]...

${bold}Commands:${normal}
  one_click       - Runs zosia website (on localhost on port 8000)
  setup           - Spins up the containers and prepares development enviromanet
  shell           - Runs Bash shell inside the container
  runserver       - Runs django development server inside the container
  test            - Runs django tests inside the container
  py_install      - Installs python dependencies specified in requirements.txt
  js_install      - Installs javascript depedencies specified in package.json
  js_watch        - Rebuilds javascript on file change (${bold}${purple}note:${normal} may create files on host fs with root permissions)
  js_build        - Builds javascript (${bold}${purple}note:${normal} may create files on host fs with root permissions)
  makemigrations  - Generates django migrations from models (${bold}${purple}note:${normal} may create files on host fs with root permissions)
  migrate         - Applies migrations of django application
  shutdown        - Kills and deletes containers
  help            - Shows this help

${bold}Options:${normal}
  --no-cache      - Do not use cache when building the container image.
  --create-admin  - Create super user account (you need to specify the password).
"


function configure_env () {
  local cwd
  cwd=$(pwd)
  cd $(dirname "${0}")
  cd ../
  ROOT_PATH=$(pwd)
  cd "${cwd}"
  DOCKER_COMPOSE="${ROOT_PATH}/docker-compose.dev.yml"
  PROJECT_NAME="zosia"
  WEB_CONTAINER_NAME="${PROJECT_NAME}_web_1"
  CREATE_ADMIN=false
}

configure_env

function build() {
  docker-compose -f ${DOCKER_COMPOSE} build ${NO_CACHE}
}

function shell() {
  docker exec -it ${WEB_CONTAINER_NAME} /bin/bash
}

function run() {
  docker exec -it ${WEB_CONTAINER_NAME} /bin/bash -c "${1}"
}

function js_install () {
  run "yarn install"
}

function js_watch () {
  run "yarn watch"
}

function js_build () {
  run "yarn build"
}

function py_install () {
  run "pip install -r requirements.txt"
}

function create_superuser () {
  run "python src/manage.py createsuperuser --email admin@zosia.org --first_name Admin --last_name Zosiowicz"
}

function makemigrations() {
  run "python src/manage.py makemigrations"
}

function migrate () {
  run "python src/manage.py migrate"

  if [ "${CREATE_ADMIN}" = true ]
  then
    echo "${bold}${purple}-- Set password for super user account --${normal}"
    create_superuser
  fi
}

function runserver () {
  run "python src/manage.py runserver 0.0.0.0:8000"
}

function runtests () {
  run "python src/manage.py test"
}

function setup () {
  build
  docker-compose -f ${DOCKER_COMPOSE} -p ${PROJECT_NAME} up -d
  js_install
  js_build
}

function shutdown () {
  docker-compose -f ${DOCKER_COMPOSE} -p ${PROJECT_NAME} down
}

function one_click () {
  echo "${bold}-- Setup container --${normal}"
  setup
  echo "${bold}-- Run migrations --${normal}"
  migrate
  echo "${bold}-- Run webserver --${normal}"
  runserver
  echo "${bold}-- Exiting - ${purple}Remember to run \`./dev.sh shutdown\`, if you've just finished${normal}"
  docker ps
}

if [[ "${#}" -eq 0 ]]
then
  echo "${HELP_TEXT}"
  exit 1
fi

command="${1}"
shift

while true
do
  case ${1} in
    --no-cache)
    NO_CACHE="--no-cache"
    ;;
    --create-admin)
    CREATE_ADMIN=true
    ;;
    "")
    break
    ;;
    *)
    echo "${red}Unknown option ${1}${normal}"
    echo "${HELP_TEXT}"
    exit 1
    ;;
  esac

  shift
done

case ${command} in
  one_click)
  one_click
  ;;
  setup)
  setup
  ;;
  runserver)
  runserver
  ;;
  py_install)
  py_install
  ;;
  shell)
  shell
  ;;
  js_watch)
  js_watch
  ;;
  js_build)
  js_build
  ;;
  js_install)
  js_install
  ;;
  shutdown)
  shutdown
  ;;
  migrate)
  migrate
  ;;
  makemigrations)
  makemigrations
  ;;
  test)
  runtests
  ;;
  help)
  echo "${HELP_TEXT}"
  ;;
  *)
  echo "${red}Unknown option ${command}${normal}"
  echo "${HELP_TEXT}"
  exit 1
  ;;
esac
