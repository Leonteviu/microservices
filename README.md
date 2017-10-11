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

## План:

- Создание docker host
- Создание своего образа
- Работа с Docker Hub

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
- $ docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
- $ docker run -d --network=reddit --network-alias=post leonteviu/post:1.0
- $ docker run -d --network=reddit --network-alias=comment leonteviu/comment:1.0
- $ docker run -d --network=reddit -p 9292:9292 leonteviu/ui:1.0
- $ docker kill $(docker ps -q) - остановить контейнеры<br>

**можно задать контейнерам другие сетевые алиасы и переопределить соответствующие переменные окружения при запуске новых контейнеров через docker run. Тогда наши команды будут выглядеть следующим образом:**

- предварительно надо остановить контейнеры **docker kill $(docker ps -q)**
- `$ docker run -d --network=reddit --network-alias=post_db_new --network-alias=comment_db_new mongo:latest` - для mongo указали два алиаса **post_db_new** и **comment_db_new**, которые будут использователься переменными, описанными при старте соответствующих контейнеров post и comment
- `$ docker run -d --network=reddit --env POST_DATABASE_HOST=post_db_new --network-alias=post_new leonteviu/post:1.0` - указана переменная **POST_DATABASE_HOST**, отличная от описанной в Dockerfile для post, а также указан новый алиас, используемый в последствии для запуска контейнера ui
- `$ docker run -d --network=reddit --env COMMENT_DATABASE_HOST=comment_db_new --network-alias=comment_new leonteviu/comment:1.0` - указана переменная **COMMENT_DATABASE_HOST**, отличная от описанной в Dockerfile для comment, а также указан новый алиас, используемый в последствии для запуска контейнера ui
- `$ docker run -d --network=reddit --env POST_SERVICE_HOST=post_new --env COMMENT_SERVICE_HOST=comment_new -p 9292:9292 leonteviu/ui:1.0` - - указаны две переменные **POST_DATABASE_HOST** и **COMMENT_DATABASE_HOST**, отличная от описанной в Dockerfile для ui

### Возможно уменьшить размер одного из наших образов, например в репозитории ui:

- $ docker images - узнаем размер наших images
- откорректируем содержимое файла **./ui/Dockerfile**, заменив **FROM** и **RUN** на:<br>
  FROM ubuntu:16.04<br>
  RUN apt-get update && apt-get install -y ruby-full ruby-dev build-essential && gem install bundler --no-ri --no-rdoc

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

### Создание docker volume и подключение к MongoDB<br>

(Для того, чтобы после выключения контейнеров данные нашего приложения не терялись, используем **docker volume**)

#### Команды:

- $ docker volume create reddit_db - создание docker volume
- $ docker kill $(docker ps -q) - выключили старые копии контейнеров<br>
  Запустим новые копии контейнеров:
- $ docker run -d --network=reddit **-v reddit_db:/data/db** --network-alias=post_db --network-alias=comment_db mongo:latest
- $ docker run -d --network=reddit --network-alias=post leonteviu/post:1.0
- $ docker run -d --network=reddit --network-alias=comment leonteviu/comment:1.0
- $ docker run -d --network=reddit -p 9292:9292 leonteviu/ui:2.0

### Задание со * - собрать образ на основе alpine linux для ui:<br>

===================================================================

- Укажем соответствующие инструкции FROM и RUN в ui/Dockerfile:<br>
  FROM alpine:3.6<br>
  RUN apk update && apk upgrade && apk --update add ruby ruby-dev ruby-json build-base && gem install bundler --no-ri --no-rdoc && rm -rf /var/cache/apk/*

  - Команды в инструкциях указаны вместо для Ubentu - **apt-get** для Linux - **apk**

- rm -rf /var/cache/apk/* - очистка кэша пакетного менеджера

- ruby-full соответствует ruby

- build-essential соответствует build-base

- ruby-json - потребовалось доустановить пакет так как:<br>
  Образ собрался, но при запуске падал.

- $ docker ps -a - посмотреть все когда-либо запускаемые контейнеры

- $ docker logs container_name - вывести лог запуска контейнера, выясним почему падал при запуске (выяснилось, что причина падения - отсутствие пакета **ruby-json**)

- $ docker build -t leonteviu/ui:**3.0** ./ui - билд образа на основе **Alpine linux**

- $ docker run -d --network=reddit -p 9292:9292 leonteviu/ui:**3.0** - запуск

# Homework 17 (branch homework-03)

# Необходимо:

- Созданный хост в GCP с помощью docker-machine `docker-machine create --driver google --google-project docker-181813 --google-zone europe-west1-b --google-machine-type g1-small --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) docker-host`
- Инициализировать переменные окружения для работы с docker-engine на созданной машине `eval $(docker-machine env docker-host)`
- Установленный `docker-compose` (<https://docs.docker.com/compose/install/#install-compose>) либо `pip install docker-compose`

## План:

- Работа с сетями в Docker
- Использование docker-compose
- Тестирование в docker

## Работа с сетями в Docker

### Файлы

### Команды

- $ docker exec -ti net_test ifconfig
- $ docker-machine ssh docker-host ifconfig
- $ docker kill $(docker ps -q)<br>

> В качестве образа используем joffotron/docker-net-tools. Делаем это для экономии сил и времени, т.к. в его состав уже входят необходимые утилиты для работы с сетью: пакеты bind-tools, net-tools и curl.

#### None network driver

- $ docker run --network none --rm -d --name net_test joffotron/docker-net-tools -c "sleep 100"

#### Host network driver

- $ docker run --network host --rm -d --name net_test joffotron/docker-net-tools -c "sleep 100"
- $ docker run --network host -d nginx<br>
  если посмотреть результат команды `docker ps`, выполнив ее несколько раз, то можно увидеть, что стартован всего один контейнер `nginx:latest`. **ПОЧЕМУ???**

#### Bridge network driver

Создадим bridge-сеть в docker<br>

- $ docker network create reddit --driver bridge<br>
  Можно запустить наши контейнеры с использованием сетевых alias:
- $ docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
- $ docker run -d --network=reddit --network-alias=post leonteviu/post:1.0
- $ docker run -d --network=reddit --network-alias=comment leonteviu/comment:1.0
- $ docker run -d --network=reddit -p 9292:9292 leonteviu/ui:3.0<br>

> На самом деле, наши сервисы ссылаются друг на друга по dns-именам, прописанным в ENV-переменных (см Dockerfile). В текущей инсталляции встроенный DNS docker не знает ничего об этих именах.

===<br>

Создадим две docker сети:

- $ docker network create back_net --subnet=10.0.2.0/24
- $ docker network create front_net --subnet=10.0.1.0/24<br>
  Запустим наши контейнеры так, чтобы в **back_net** находились **post**, **commect** и **mongo_db**, а в **front_net** - **ui**:
- $ docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest
- $ docker run -d --network=back_net --name post leonteviu/post:1.0
- $ docker run -d --network=back_net --name comment leonteviu/comment:1.0
- $ docker run -d --network=front_net -p 9292:9292 --name ui leonteviu/ui:1.0

  > Docker при инициализации контейнера может подключить к нему только 1 сеть. При этом контейнеры из соседних сетей не будут доступны как в DNS, так и для взаимодействия по сети. Поэтому нужно поместить контейнеры **post** и **comment** в обе сети.

Подключим дополнительные сети для post и comment:

- $ docker network connect front_net post
- $ docker network connect front_net comment<br>

====== Задание со ЗВЕЗДОЧКОЙ настроим **docker-proxy**, используя Bridge network driver:<br>
В нашей поднятой инфраструктуре остановим контейнер **ui**

- $ docker ps
- $ docker kill ui_conteiner_id
- $ docker rm $(docker ps -a -q -f status=exited) - удалим все остановленные контейнеры (можно выбрать конкретно наш)
- $ docker run -d --network=front_net -p 80:9292 --name ui leonteviu/ui:1.0 - пробросили наше приложение на 80 порт. Теперь оно доступно по адресу <http://docker-host_IP> (Предварительно на нашей docker-machine в GCP необходимо разрешить http)<br>

Посмотрим как выглядит сетевой стек Linux в текущий момент:

1. Зайти по ssh на docker-host и установите пакет bridge-utils (ссылка на gist):

  - $ docker-machine ssh docker-host
  - $ sudo apt-get update && sudo apt-get install bridge-utils

2. Выполнить:

  - $ docker-network ls
  - $ ifconfig | grep br - посмотрть bridge-интерфейсы
  - $ brctl show
  - $ brctl show interface

    > Отображаемые veth-интерфейсы - это те части виртуальных пар интерфейсов, которые лежат в сетевом пространстве хоста и также отображаются в ifconfig. Вторые их части лежат внутри контейнеров

3. Посмотрим, как выглядит iptables:

  - $ sudo iptables -nL -t nat

    > POSTROUTING отвечают за выпуск во внешнюю сеть контейнеров из bridge-сетей

    > DOCKER и правила DNAT отвечают за перенаправление трафика на адреса уже конкретных контейнеров.

  - $ ps ax | grep docker-proxy

    > должны увидеть хотя бы 1 запущенный процесс docker-proxy. Этот процесс в данный момент слушает сетевой tcp-порт 9292.

====== Конец задания со ЗВЕЗДОЧКОЙ

## Использование docker-compose

- Предварительно надо остановить все запущенные контейнеры `docker rm -f $(docker ps -a -q)` - удалит вообще все контейнеры

### Файлы

- ~/microservices/docker-compose.yml

### Команды

> Отметим, что docker-compose поддерживает интерполяцию(подстановку) переменных окружения. В данном случае это переменная USERNAME. Поэтому перед запуском необходимо экспортировать значения данных переменных окружения

- $ export USERNAME=your-login
- $ docker-compose up -d - запускает полностью весь наш проект, описанный в docker-compose.yml
- $ docker-compose ps

Очистить нами созданное можно при помощи команд:<br>

- $ docker rm -f $(docker ps -a -q) удаляет все контейнеры
- $ docker network ls - отображает имеющиеся сети
- $ docker network rm microservices_front_net -удаляет сеть microservices_front_net
- $ docker network rm microservices_back_net

#### параметризуем наш файл docker-compose.yml

Описаны следующие переменные в docker-compose.yml:

- CONTAINER_PORT - порт в контейнере ui
- EXTERNAL_PORT - порт, смотрящий наружу
- PROTOCOL - протоколы наших портов
- POST_VERSION - версия сервиса post
- COMMENT_VERSION - версия сервиса comment
- UI_VERSION - версия сервиса ui
- FRONT_SUBNET - docker сеть ui
- BACK_SUBNET - docker сеть mongo

  > post и comment сервисы находятся в обеих сетях

- ~/microservices/.env - файл, содержащий значение переменных, используемых при параметризации docker-compose.yml<br>

Для старта используется все та же команда `docker-compose up -d`

## Тестирование в docker

### Файлы

### Команды
