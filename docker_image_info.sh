#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/docker_info.log"
log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
  echo -e "${RED}Ошибка: $1${NC}" | tee -a "$LOG_FILE"
  exit 1
}

check_docker() {
  if ! command -v docker &> /dev/null; then
    error "Docker не установлен. Установите Docker и повторите попытку."
  fi
}

usage() {
  echo -e "${YELLOW}Использование: $0 [опции] <имя_образа или ID_образа>${NC}"
  echo -e "${YELLOW}Опции:${NC}"
  echo -e "  --format <text|json>   Формат вывода (по умолчанию: text)"
  echo -e "  --filter <ключ=значение>  Фильтрация контейнеров по меткам"
  echo -e "  --compose-file <файл>  Использование Docker Compose файла"
  echo -e "  --export <csv|json>    Экспорт данных в файл"
  echo -e "  --interactive          Интерактивный режим"
  echo -e "  --help                 Показать эту справку"
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        FORMAT="$2"
        shift 2
        ;;
      --filter)
        FILTER="$2"
        shift 2
        ;;
      --compose-file)
        COMPOSE_FILE="$2"
        shift 2
        ;;
      --export)
        EXPORT_FORMAT="$2"
        shift 2
        ;;
      --interactive)
        INTERACTIVE=1
        shift
        ;;
      --help)
        usage
        ;;
      *)
        IMAGE="$1"
        shift
        ;;
    esac
  done

  if [ -z "$IMAGE" ]; then
    error "Не указан образ или ID."
  fi
}

get_containers() {
  if [ -n "$COMPOSE_FILE" ]; then
    log "Использование Docker Compose файла: $COMPOSE_FILE"
    CONTAINER_IDS=$(docker-compose -f "$COMPOSE_FILE" ps -q)
  else
    FILTER_ANCESTOR="ancestor=$IMAGE"
    if [ -n "$FILTER" ]; then
      CONTAINER_IDS=$(docker ps -q --filter "$FILTER_ANCESTOR" --filter "$FILTER")
    else
      CONTAINER_IDS=$(docker ps -q --filter "$FILTER_ANCESTOR")
    fi
  fi

  if [ -z "$CONTAINER_IDS" ]; then
    log "Нет запущенных контейнеров из образа $IMAGE"
    exit 0
  fi
}

inspect_container() {
  local CONTAINER_ID=$1
  local FORMAT=${2:-text}

  if [ "$FORMAT" == "json" ]; then
    docker inspect --format '{{json .}}' "$CONTAINER_ID"
  else
    echo -e "${GREEN}Информация по контейнеру $CONTAINER_ID:${NC}"
    docker inspect --format '
ID: {{.Id}}
Имя: {{.Name}}
Статус: {{.State.Status}}
Запущен: {{.State.StartedAt}}
Образ: {{.Config.Image}}
Команда: {{.Config.Cmd}}
Порты: {{.NetworkSettings.Ports}}
IP-адрес: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
MAC: {{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}
Шлюз: {{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}
Метки: {{.Config.Labels}}
Рестарт политика: {{.HostConfig.RestartPolicy.Name}}
Привилегии: {{.HostConfig.Privileged}}
' "$CONTAINER_ID"
  fi
}

export_data() {
  local CONTAINER_ID=$1
  local FORMAT=$2

  case "$FORMAT" in
    csv)
      docker inspect --format '
{{.Id}},{{.Name}},{{.State.Status}},{{.Config.Image}},{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
' "$CONTAINER_ID" >> containers.csv
      ;;
    json)
      docker inspect --format '{{json .}}' "$CONTAINER_ID" >> containers.json
      ;;
    *)
      error "Неизвестный формат экспорта: $FORMAT"
      ;;
  esac
}

interactive_mode() {
  echo -e "${YELLOW}Выберите контейнер:${NC}"
  select CONTAINER_ID in $CONTAINER_IDS; do
    if [ -n "$CONTAINER_ID" ]; then
      inspect_container "$CONTAINER_ID" "$FORMAT"
      if [ -n "$EXPORT_FORMAT" ]; then
        export_data "$CONTAINER_ID" "$EXPORT_FORMAT"
      fi
      break
    else
      echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
    fi
  done
}

main() {
  check_docker
  parse_args "$@"
  get_containers

  if [ -n "$INTERACTIVE" ]; then
    interactive_mode
  else
    for CONTAINER_ID in $CONTAINER_IDS; do
      inspect_container "$CONTAINER_ID" "$FORMAT"
      if [ -n "$EXPORT_FORMAT" ]; then
        export_data "$CONTAINER_ID" "$EXPORT_FORMAT"
      fi
    done
  fi
}

main "$@"
