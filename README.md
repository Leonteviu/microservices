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

# Homework 16 (branch homework-02)

## План

- Разбить наше приложение на несколько компонент
- Запустить наше микросервисное приложение<br>

Все предыдущие наработки (db_config, Dockerfile, mongod.conf,README.md, start.sh) переместили в созданную директорию **monolith**<br>

## Файлы:

Новая структура нашего приложения (**для работы ему требуется mongodb**) теперь состоит из:

- post-py - сервис отвечающий за написание постов
- comment - сервис отвечающий за написание комментариев
- ui - веб-интерфейс для других сервисов

## Команды:

- $ docker pull mongo:latest - скачать последний образ mongodb<br>

Сборка образов с нашими сервисами:

- $ docker build -t leonteviu/post:1.0 ./post-py
- $ docker build -t leonteviu/comment:1.0 ./comment
- $ docker build -t leonteviu/ui:1.0 ./ui<br>
  (сборка **ui** началась не с первого шага потому, что инструкции в Dockerfile для ui уже были выполнены (**кэшировались**) при сборке comment (до команды ADD Gemfile* $APP_HOME/))<br>

Запуск приложения:<br>
(Добавим сетевые алиасы контейнерам. Сетевые алиасы могут быть использованы для сетевых соединений, как доменные имена)

- $ docker network create reddit - создать bridge-сеть для контейнеров, так как сетевые алиасы не работают в сети по-умолчанию
- $ docker run -d --network=reddit \<br>
  --network-alias=post_db --network-alias=comment_db mongo:latest
- $ docker run -d --network=reddit \<br>
  --network-alias=post leonteviu/post:1.0
- $ docker run -d --network=reddit \<br>
  --network-alias=comment leonteviu/comment:1.0
- $ docker run -d --network=reddit \<br>
  -p 9292:9292 leonteviu/ui:1.0
