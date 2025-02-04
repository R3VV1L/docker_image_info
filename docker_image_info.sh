#!/bin/bash

# Проверяем, что передан аргумент с именем образа или ID
if [ -z "$1" ]; then
  echo "Использование: $0 <имя_образа или ID_образа>"
  exit 1
fi

# Получаем ID контейнеров, запущенных из указанного образа
CONTAINER_IDS=$(docker ps -q --filter ancestor="$1")

# Проверяем, есть ли запущенные контейнеры
if [ -z "$CONTAINER_IDS" ]; then
  echo "Нет запущенных контейнеров из образа $1"
  exit 0
fi

# Выводим информацию по каждому контейнеру
for CONTAINER_ID in $CONTAINER_IDS; do
  echo "Информация по контейнеру $CONTAINER_ID:"
  
# Извлекаем и выводим ключевые данные
  docker inspect --format='
ID: {{.Id}}
Имя: {{.Name}}
Статус: {{.State.Status}}
Запущен: {{.State.StartedAt}}
Образ: {{.Config.Image}}
Команда: {{.Config.Cmd}}
Порты: {{.NetworkSettings.Ports}}
IP-адрес: {{.NetworkSettings.Networks}}{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
' "$CONTAINER_ID"
done
