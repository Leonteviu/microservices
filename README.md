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
- $ docker kill $(docker ps -q) - остановить контейнеры<br>

**можно задать контейнерам другие сетевые алиасы и переопределить соответствующие переменные окружения при запуске новых контейнеров через docker run. Тогда наши команды будут выглядеть следующим образом:**

- предварительно надо остановить контейнеры **docker kill $(docker ps -q)**
- $ docker run -d --network=reddit \<br>
  --network-alias=post_db_new --network-alias=comment_db_new mongo:latest - для mongo указали два алиаса **post_db_new** и **comment_db_new**, которые будут использователься переменными, описанными при старте соответствующих контейнеров post и comment
- $ docker run -d --network=reddit \<br>
  --env POST_DATABASE_HOST=post_db_new --network-alias=post_new leonteviu/post:1.0 - указана переменная **POST_DATABASE_HOST**, отличная от описанной в Dockerfile для post, а также указан новый алиас, используемый в последствии для запуска контейнера ui
- $ docker run -d --network=reddit \<br>
  --env COMMENT_DATABASE_HOST=comment_db_new --network-alias=comment_new leonteviu/comment:1.0 - указана переменная **COMMENT_DATABASE_HOST**, отличная от описанной в Dockerfile для comment, а также указан новый алиас, используемый в последствии для запуска контейнера ui
- $ docker run -d --network=reddit \<br>
  --env POST_SERVICE_HOST=post_new --env COMMENT_SERVICE_HOST=comment_new -p 9292:9292 leonteviu/ui:1.0 - - указаны две переменные **POST_DATABASE_HOST** и **COMMENT_DATABASE_HOST**, отличная от описанной в Dockerfile для ui

### Возможно уменьшить размер одного из наших образов, например в репозитории ui:

- $ docker images - узнаем размер наших images
- откорректируем содержимое файла **./ui/Dockerfile**, заменив **FROM** и **RUN** на:<br>
  FROM ubuntu:16.04<br>
  RUN apt-get update \<br>
  && apt-get install -y ruby-full ruby-dev build-essential \<br>
  && gem install bundler --no-ri --no-rdoc

**!** В процессе сборки может появиться ошибка:<br>
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.<br>
...................<br>
Make sure that `gem install unf_ext -v '0.0.7.4'` succeeds before bundling.<br>
...................<br>
The command '/bin/sh -c bundle install' returned a non-zero code: 5<br>

В этом случае необходимо **пересоздать docker-machine**, указав тип нашины **g1-small**:<br>

- $ docker-machine create --driver google --google-project docker-181813 --google-zone europe-west1-b **--google-machine-type g1-small** --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) docker-host<br>

**!**

#### Команды:

- $ docker build -t leonteviu/ui:2.0 ./ui - пересоберем ui
- $ docker run -d --network=reddit -p 9292:9292 leonteviu/ui:2.0 - запустим контейнер
