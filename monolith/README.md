# microservices

- Зарегистрироватья на Docker hub (<https://hub.docker.com/>)
- Для работы потребуется установленный Docker (<https://docs.docker.com/machine/install-machine/>)
- Создать новый проект в GCE и назвать его docker
- ID нашего проекта **docker-181813**
- Установите GCloud SDK (<https://cloud.google.com/sdk/>)
- Сконфигурировать gcloud (выполнив команду gcloud init)
- Выполнить gcloud auth (получили файл с аутентификационными данными. Он будет использоваться docker-machine для работы с облаком.)
- создайте репозиторий "microservices" на GitHub'е

# Homework 15 (branch homework-01)

- Для доступа к нашему приложению понадобиться создать правило в filewall (Название => reddit-app, Теги целевых экземпляров => docker-machine, Диапазоны IP-адресов источников => 0.0.0.0/0, ротоколы и порты => Указанные протоколы и порты => tcp:9292)

## Файлы:

- ~/microservices/Dockerfile - текстовое описание нашего образа
- ~/microservices/mongod.conf - подготовленный конфиг для mongodb
- ~/microservices/db_config - содержит переменную со ссылкой на mongodb
- ~/microservices/start.sh - скрипт запуска приложения

## Команды:

- $ docker-machine create --driver google --google-project docker-181813 --google-zone europe-west1-b --google-machine-type f1-micro --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) docker-host - создание docker-machine
- docker-machine ls - посмотреть имеющиеся docker-machines и их состояние
- $ eval $(docker-machine env docker-host)
- $ docker run --rm -ti tehbilly/htop
- $ docker run --rm --pid host -ti tehbilly/htop

- $ docker build -t reddit:latest . - собрать образ

- $ docker images -a

- $ docker run --name reddit -d --network=host reddit:latest - запустить контейнер
