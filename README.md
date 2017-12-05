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

## Работа с сетями в Docker

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
  если посмотреть результат команды `docker ps`, выполнив ее несколько раз, то можно увидеть, что стартован всего один контейнер `nginx:latest`.

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

Описаны следующие переменные в docker-compose.yml:<br>
Важно отметить, что так как ранее мы присвоили переменной USERNAME определенное значение `export USERNAME=your-login`, то для использования этой переменной в файле .env на необходимо убрать это значение `unset USERNAME`, `export USERNAME` перезагрузить систему.

- USERNAME
- MONGO_VER - версия mongo
- CONTAINER_PORT - порт в контейнере ui
- EXTERNAL_PORT - порт, смотрящий наружу
- PROTOCOL - протоколы наших портов
- POST_VERSION - версия сервиса post
- COMMENT_VERSION - версия сервиса comment
- UI_VERSION - версия сервиса ui
- FRONT_SUBNET - docker сеть ui
- BACK_SUBNET - docker сеть mongo

  > post и comment сервисы находятся в обеих сетях

- ~/microservices/.env.example - файл-шаблон (он может и не содержать значения переменных, переменные могут быть просто перечислены), содержащий значение переменных, используемых при параметризации `docker-compose.yml`. Из .env.example создается файл `~/microservices/.env`, в котором уже описываются необходимые значения переменных (`.env` добавлен в `.gitignore`). docker-compose должен подхватить переменные из этого файла `~/microservices/.env`<br>

Для старта используется все та же команда `docker-compose up -d`

====== Задание со звездочкой (COMPOSE_PROJECT_NAME)<br>
По-умолчанию значение COMPOSE_PROJECT_NAME = имя_каталога_проекта.<br>
Для того, чтобы задать другое базовое имя проетка, например **hw17**, есть два пути:

- Задать имя переменной COMPOSE_PROJECT_NAME, например `export COMPOSE_PROJECT_NAME=hw17`
- Для поднятия наших сервисов с помощью compose файла использовать команду `docker-compose -p hw17 up -d`

# Homework 21 (branch monitoring-1)

## План

### Prometheus: запуск, конфигурация, знакомство с Web UI

### Мониторинг состояния микросервисов

### Сбор метрик хоста с использованием экспортера

## Необходимо:<br>

Подготовить окружение:

> Прежде всего необходимо выбрать конфигурацию **gcloud**<br>
> $ `**gcloud init**` Выберем наш проект **infra-XXXXXX**, в котором будем работать<br>

- Создать правило файрвола для **Prometheus** и **Puma**

  - $ `gcloud compute firewall-rules create prometheus-default --allow tcp:9090`
  - $ `gcloud compute firewall-rules create puma-default --allow tcp:9292`

- Создать Docker хост в GCE и настроим локальное окружение на работу с ним:

  - $ `docker-machine create --driver google --google-project infra-179710 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts --google-machine-type n1-standard-1 --google-zone europe-west1-b vm1`
  - $ `eval $(docker-machine env vm1)`

### Prometheus: запуск, конфигурация, знакомство с Web UI

> Систему мониторинга Прометей будем запускать внутри Docker контейнера. Для начального знакомства воспользуемся готовым образом с DockerHub.

WEB-интерфейс будет находится по адресу <http://IP_vm1:9090/graph>

> $`docker-machine ip vm1` - узнать адрес vm1

#### Файлы:

- ~/microservices/prometheus/Dockerfile - для сбора на основе готового образа с DockerHub Docker образа с конфигурацией для мониторинга наших микросервисов
- ~/microservices/prometheus/prometheus.yml - конфигурационный файл Прометея

> Будем поднимать наш Прометей совместно с микросервисами.<br>
> Определите в вашем docker-compose.yml файле, сервис Прометея.<br>
> Добавим сервис `prometheus:` в `docker-compose.yml`<br>

> Мы будем использовать Прометей для мониторинга всех<br>
> наших микросервисов, поэтому нам необходимо, чтобы<br>
> контейнер с Прометеем мог общаться по сети со всеми<br>
> другими сервисами, определенными в компоуз файле.<br>
> Добавим секцию networks в определение<br>
> сервиса Прометея в docker-compose.yml.

#### Команды:

- $ `docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus` - запуск контейнера
- $ `docker ps`
- $ `docker stop prometheus` - остановка контейнера<br>

- $ `export USERNAME=leonteviu` - USERNAME - ваш логин от DockerHub

- $ `docker build -t $USERNAME/prometheus .` - собирем Docker образ в директории prometheus

> Код микросервисов обновился, мы добавили туда healthcheck-и<br>
> для проверки работоспособности нашего приложения. Сборку<br>
> образов теперь необходимо производить при помощи скриптов<br>
> `docker_build.sh`, которые появились в каждой директории<br>
> сервиса. С его помощью мы будем использовать информацию Git<br>
> репозитория в нашем healthcheck-е.

- $ `bash ui/docker_build.sh` - сборка микросервиса ui
- $ `bash post-py/docker_build.sh` - сборка микросервиса post-py
- $ `bash comment/docker_build.sh` - сборка микросервиса comment
- $ `docker-compose up -d` - запуск микросервисов

### Мониторинг состояния микросервисов

#### Файлы:

#### Команды:

### Сбор метрик хоста с использованием экспортера

> Экспортер похож на вспомогательного агента для сбора метрик.<br>
> В ситуациях, когда мы не можем реализовать отдачу метрик Прометею в<br>
> коде приложения, мы можем использовать экспортер, который будет<br>
> транслировать метрики приложения или системы в формате доступном для<br>
> чтения Прометеем.<br>

Используем [Node экспортер](https://github.com/prometheus/node_exporter) для сбора информации о работе Docker хоста<br>
(виртуалки, где у нас запущены контейнеры) и предоставлению этой<br>
информации Прометею.<br>

Node экспортер будем запускать также в контейнере.<br>
Определим еще один сервис **node-exporter:** в docker-compose.yml файле.<br>

> Не забудем добавить секцию networks в определение<br>
> сервиса node-exporter в docker-compose.yml.

Чтобы сказать Прометею следить за еще одним сервисом,<br>
нам нужно добавить информацию об этом сервисе в конфиг Прометея.<br>
Добавим еще один job: `- job_name: 'node'`

> Не забудем собрать новый Docker образ для Прометея,<br>
> и пересоздать наши сервисы

#### Файлы:

#### Команды:

- $ `docker build -t $USERNAME/prometheus .` - собрать новый Docker образ для Прометея
- $ `docker-compose down`
- $ `docker-compose up -d`

## Задание со звездочкой

### 1\. Сделать мониторинг MongoDB с использованием экспортера

Используем [MongoDB exporter](https://hub.docker.com/r/crobox/mongodb-exporter) для сбора информации о работе MongoDB

#### Файлы:

- ~/microservices/prometheus/prometheus.yml - в этот файл добавили новый job `mongodb`, чтобы Прометей мог следить за Монгой
- ~/microservices/docker-compose.yml - описали сервис `mongodb-exporter`, указав переменную `MONGODB_URL` (например, MONGODB_URL=mongodb://mongo_db:27017)

#### Команды:

> Директорию ~/microservices/mongodb_exporter удалим за ненадобностью, так как у нас есть необходимый образ

- $ `docker-compose down`

- $ `docker-compose up -d`

> Можно и самим собрать образ Используем [MongoDB exporter](https://github.com/dcu/mongodb_exporter) для сбора информации о работе MongoDB

> - $ `git clone git@github.com:dcu/mongodb_exporter.git ~/microservices/mongodb_exporter`
> - $ `cd ~/microservices/mongodb_exporter`
> - $ `docker build -t $USERNAME/mongodb-exporter .`

# Homework 22-23 (branch monitoring-2)

## План

- Мониторинг Docker контейнеров
- Визуализация метрик
- Сбор метрик работы приложения и бизнес метрик
- Настройка алертинга

## Необходимо

Создадим Docker хост в GCE и настроим локальное окружение на работу с ним (infra-179710 - ID нашего репозитория)

- $ `docker-machine create --driver google --google-project infra-179710 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts --google-machine-type n1-standard-1 --google-zone europe-west1-b --google-open-port 80/tcp --google-open-port 3000/tcp --google-open-port 8080/tcp --google-open-port 9090/tcp --google-open-port 9292/tcp vm1`
- $ `eval $(docker-machine env vm1)`

## Мониторинг Docker контейнеров

### cAdvisor (<http://docker-machine-host-ip:8080>)

> Мы будем использовать [cAdvisor](https://github.com/google/cadvisor) для наблюдения за состоянием наших Docker контейнеров.<br>
> cAdvisor собирает информацию о ресурсах потребляемых контейнерами и характеристиках их работы.<br>
> Примерами метрик являются:<br>
> процент использования контейнером CPU и памяти, выделенные для его запуска, объем сетевого трафика и др.<br>

#### Файлы:

- ~/microservices/docker-compose.yml - добавили информацию о новом сервисе **cadvisor**

  > не забыть поместите данный сервис в одну сеть с Прометеем, чтобы тот мог собирать с него метрики<br>

- ~/microservices/prometheus/prometheus.yml - добавили информацию о новом сервисе **cadvisor**

#### Команды:

- $ `export USER_NAME=leonteviu`
- $ `docker build -t $USER_NAME/prometheus .`
- $ `docker-compose up -d`

## Визуализация метрик (Grafana <http://docker-mahine-host-ip:3000>)

> Используем инструмент [Grafana](https://github.com/grafana/grafana) для визуализации основных метрик Docker контенеров.

> На сайте Grafana можно найти и скачать большое количество уже созданных официальных и<br>
> комьюнити [дашбордов](https://grafana.com/dashboards) для визуализации различного типа метрик<br>
> для разных систем мониторинга и баз данных

### Файлы:

- ~/microservices/docker-compose.yml - добавили информацию о новом сервисе **grafana**

  > не забыть поместите данный сервис в одну сеть с Прометеем, чтобы тот мог собирать с него метрики<br>

- ~/microservices/dashboards - директория для скаченных дашбордов

### Команды:

- $ `docker-compose up -d grafana`

## Сбор метрик работы приложения и бизнес метрик

### 1\. Сбор метрик приложения

#### Мониторинг работы приложения

> В качестве примера метрик приложения в сервис UI мы добавили:<br>
> • счетчик `ui_request_count`, который считает каждый приходящий HTTP запрос (добавляя через лейблы такую<br>
> информацию как HTTP метод, путь, код возврата, мы уточняем данную метрику)<br>
> • гистограмму `ui_request_latency_seconds`, которая позволяет отслеживать информацию о времени обработки<br>
> каждого запроса<br>

> В качестве примера метрик приложения в сервис Post мы добавили:<br>
> • Гистограмму `post_read_db_seconds`, которая позволяет отследить информацию о времени требуемом для поиска<br>
> поста в БД<br>

##### Файлы:

- ~/microservices/prometheus.yml - добавили информацию о post сервисе в конфигурацию Прометея, чтобы он начал собирать метрики и с него

  ##### Команды:

- $ `bash ui/docker_build.sh` - сборка микросервиса ui

- $ `bash post-py/docker_build.sh` - сборка микросервиса post-py

- $ `bash comment/docker_build.sh` - сборка микросервиса comment

- $ `docker-compose up -d` - запуск микросервисов

### 2\. Сбор метрик бизнес логики

> В качестве примера метрик бизнес логики мы в наше приложение мы добавили счетчики количества постов и комментариев, соответственно в post-py/post_app.py и в comment/comment_app.rb:<br>
> • post_count<br>
> • comment_count<br>

## Настройка алертинга

### Файлы:

- ~/microservices/alertmanager - директория для алертменеджера
- ~/microservices/alertmanager/config.yml - описано определение отправки нотификаций в ваш тестовый Slack канал
- ~/microservices/alertmanager/Dockerfile
- ~/microservices/docker-compose.yml - добавили новый сервис alertmanager
- ~/microservices/prometheus/alert.rules - определим условия при которых должен срабатывать алерт и посылаться Alertmanager-у
- ~/microservices/prometheus/prometheus.yml - Добавим информацию о правилах, в конфиг Прометея

### Команды:

- $ `docker build -t $USER_NAME/alertmanager .` - Соберем образ alertmanager (выполнить в директории alertmanager)
- $ `docker build -t $USER_NAME/prometheus .` - пересоберем Прометей после добавления алертинга
- $ `docker-compose stop prometheus`
- $ `docker-compose rm prometheus`
- $ `docker-compose up -d prometheus`
- $ `docker-compose up -d alertmanager`

## Задание со звездочкой:

[Stackdriver](https://github.com/frodenas/stackdriver_exporter)

# Homework 26-27 (branch docker-swarm)

## План

- Построить кластер Docker Swarm
- Конфигурирование приложения и сервисов для Docker Swarm

### Необходимо

Код микросервиса ui обновился для добавления функционала считывания переменных окружений **host_info** и **env_info** (файлы ui/ui_app.rb и ui/views/layout.haml).

- $ `export USER_NAME=<Docker_ID>`
- $ `bash ui/docker_build.sh` - сборка микросервиса ui
- $ `bash post-py/docker_build.sh` - сборка микросервиса post-py
- $ `bash comment/docker_build.sh` - сборка микросервиса comment

## Построим кластер Docker Swarm

### Файлы:

### Команды:

- $ `docker-machine create --driver google --google-project infra-179710 --google-zone europe-west1-b --google-machine-type g1-small --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) master-1`
- $ `docker-machine create --driver google --google-project infra-179710 --google-zone europe-west1-b --google-machine-type g1-small --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) worker-1`
- $ `docker-machine create --driver google --google-project infra-179710 --google-zone europe-west1-b --google-machine-type g1-small --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) worker-2`

- $ `eval $(docker-machine env master-1)`

- $ `docker swarm init` - Инициализируем Swarm-mode

  > P.S. если на сервере несколько сетевых интерфейсов или<br>
  > сервер находится за NAT, то необходимо указывать флаг<br>
  > --advertise-addr с конкретным адресом публикации.<br>
  > По-умолчанию это будет <адрес интерфейса>:2377<br>

- $ `docker swarm join-token manager/worker` - также, при необходимости, для добавления нод можно сгенерировать токен с помощью этой команды

На хостах worker-1 и worker-2 соответственно выполним:

- $ `eval $(docker-machine env worker-1)`

- $ `docker swarm join --token <ваш токен> <advertise адрес manager’a>:2377`

- $ `eval $(docker-machine env worker-2)`

- $ `docker swarm join --token <ваш токен> <advertise адрес manager’a>:2377`

  > Подключаемся к master-1 ноде (ssh или eval $(docker-machine ...))<br>
  > Дальше работать будем только с ней. Команды в рамках Swarm-<br>
  > кластера можно запускать только на Manager-нодах.<br>

- $ `eval $(docker-machine env master-1)`

- $ `docker node ls` - проверить состояние кластера

## Конфигурирование приложения и сервисов для Docker Swarm

### 1.\ Stack

> Сервисы и их зависимости объединяем в Stack<br>
> Stack описываем в формате docker-compose (YML)<br>

#### Команды:

- $ `docker stack deploy/rm/services/ls STACK_NAME` - Управляем стеком с помощью команд
- $ `docker stack deploy --compose-file docker-compose.yml ENV` - выдает ошибку, так как не поддерживает переменные окружения и .env файлы (ENV - имя стека)
- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV` - Workaround подставляет все переменные в `docker-compose.yml`, который в таком виде уже понятен нашей команде `docker stack deploy --compose-file docker-compose.yml ENV`
- $ `docker stack services DEV` - посмотреть состояние стека. Будете выведена своданая информация по сервисам (не по контейнерам)

### 2\. Размещаем сервисы

> #### 2.1 Labels

> Ограничения размещения определяются с помощью логических<br>

> действий со значениями label-ов (медатанных) нод и docker-engine'ов<br>
> Обращение к встроенным label'ам нод - `node.*`<br>
> Обращение к заданным вручную label'ам нод - `node.labels*`<br>
> Обращение к label'ам engine - `engine.labels.*`<br>
> Примеры:<br>

> - node.labels.reliability == high<br>

> - node.role != manager<br>

> - engine.labels.provider == google<br>

> #### Команды:

> - $ `docker node update --label-add reliability=high master-1` - Добавим label к ноде
> - $ `docker node ls --filter "label=reliability"` - [Swarm не умеет фильтровать вывод по label-ам нод пока что](https://github.com/moby/moby/issues/27231)
> - $ `docker node ls -q | xargs docker node inspect -f '{{ .ID }} [{{ .Description.Hostname }}]: {{ .Spec.Labels }}'` - Посмотреть label'ы всех нод

#### Файлы:

- `microservices/docker-compose.yml` - Определим с помощью **placement constraints** ограничения размещения MongoDB, post, comment и ui.

#### Команды:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV`

### 3\. Масштабируем сервисы

> Существует 2 варианта запуска:<br>
> replicated mode - запустить определенное число задач (default)<br>
> global mode - запустить задачу на каждой ноде<br>
> **!!! Нельзя заменить replicated mode на global mode (и обратно) без удаления сервиса**<br>

#### 3.1 Replicated mode

#### Файлы:

- `microservices/docker-compose.yml` - Определим с помощью **replicated mode** запустим сервисы MongoDB, post, comment и ui в нескольких экземплярах.

#### Команды:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV` - Сервисы должны были распределиться равномерно по кластеру
- $ `docker stack services DEV`
- $ `docker stack ps DEV`

  > Можно управлять количеством запускаемых сервисов "на лету"<br>
  > $ `docker service scale DEV_ui=3`<br>
  > или<br>
  > $ `docker service update --replicas 3 DEV_ui`<br>
  > Выключить все задачи сервиса:<br>
  > $ `docker service update --replicas 0 DEV_ui`<br>

#### 3.2 Globl mode

> Для задач мониторинга кластера нам понадобится запускать<br>
> node_exporter (только в 1-м экземпляре)<br>

#### Файлы:

- `microservices/docker-compose.yml` - Определим с помощью **global mode** сервис node_exporter

#### Команды:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV` - Сервисы должны были распределиться равномерно по кластеру
- $ `docker stack services DEV`
- $ `docker stack ps DEV`

### 4\. Rolling Update

#### Файлы:

- `microservices/docker-compose.yml` - Определим с помощью **update_config** параметры обновления (приложение UI должно обновляться группами по 1 контейнеру с разрывом в 5 секунд. В случае возникновения проблем деплой откатиться, сервисы post и comment обновлялются группами по 2 сервиса с разрывом в 10 секунд, а в случае неудач осуществлялся rollback)

  > parallelism - cколько контейнеров (группу) обновить одновременно?<br>
  > delay - задержка между обновлениями групп контейнеров<br>
  > order - порядок обновлений (сначала убиваем старые и запускаем<br>
  > новые или наоборот) (только в compose 3.4)<br>
  > **Обработка ошибочных ситуаций:**<br>
  > failure_action - что делать, если при обновлении возникла ошибка<br>
  > monitor - сколько следить за обновлением, пока не признать его<br>
  > удачным или ошибочным<br>
  > max_failure_ratio - сколько раз обновление может пройти с ошибкой<br>
  > перед тем, как перейти к failure_action<br>

> **Важно отметить!** Если вы перезаписали тег рабочего приложения, то откатить<br>
> его не получится!!! Приложение будет сломано!<br>

#### Команды:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV`

### 5\. Ограничиваем ресурсы

> С помощью resources limits описываем максимум потребляемых приложениями CPU и памяти.<br>
> Это обеспечит нам:<br>
> представление о том, сколько ресурсов нужно приложению;<br>
> контроль Docker за тем, чтобы никто не превысил заданного порога (спомощью cgroups);<br>
> защиту сторонних приложений от неконтролируемого расхода ресурса контейнером;<br>

#### Файлы:

- `microservices/docker-compose.yml` - С помощью **resources limits** описываем максимум потребляемых приложениями service CPU и памяти

#### Команды:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV`

### 6\. Restart policy

> Если контейнер в рамках задачи завершит свою работу, то планировщик<br>
> Swarm автоматически запустит новый (даже если он вручную остановлен).<br>
> Мы можем поменять это поведение (для целей диагностики, например)<br>
> так, чтобы контейнер перезапускался только при падении контейнера (on-failure).<br>
> По-умолчанию контейнер будет бесконечно перезапускаться. Это может<br>
> оказать сильную нагрузку на машину в целом.<br>

#### Файлы:

- `microservices/docker-compose.yml` - **restart_policy** - ограничим число попыток перезапуска

### Задание

Выделим инфраструктуру, описывающую мониторинг в отдельный файл `docker-compose.infra.yml`<br>
Основые сервисы приложения (MongoDB, UI, Post, Comment) оставим в файле `docker-compose.yml`

Для запуска приложения вместе с инфрой можно использовать следующую команду:

- $ `docker stack deploy --compose-file=<(docker-compose -f docker-compose.infra.yml -f docker-compose.yml config 2>/dev/null) DEV`

### Задание _*_

> Как вы видите управление несколькими окружениями с помощью .env-файлов<br>
> и compose-файлов в Swarm?<br>
> Создайте такие .env-файлы и параметризуйте что считаете нужным в compose-файлах.<br>
> Напишите команды, с помощью которых вы запустите эти несколько окружений<br>
> рядом (в кластере) в README-файле.<br>

#### Файлы:

Разнесем наши окружения по разным директориям<br>
По-умолчанию, все контэйнеры, которые запускаются с помощью docker-compose, используют название текущей директории как префикс. Название этой директории может отличаться в рабочих окружениях. Этот префикс используется, когда мы хотим сослаться на контейнер из основного docker-compose файла. Чтобы зафиксировать этот префикс, нужно создать файл .env в той директории, из которой запускается docker-compose, указав в нем переменную:<br>
**COMPOSE_PROJECT_NAME=microservices**<br>
Таким образом, префикс будет одинаковым во всех рабочих окружениях.

- `microservices/compose_main` - содержит `docker-compose.yml` и `.env`, описывающие, соответственно, сервисы нашего приложения (MongoDB, UI, Post, Comment) и используемые здесь переменные
- `microservices/compose_infra` - содержит `docker-compose.yml` и `.env`, описывающие, сервисы мониторинга (Prometheus, Alertmanager, Node-exporter, mongodb-exporter, stackdriver, Grafana, cAdvisor), а также используемые здесь переменные.<br>

Примеры файлов с описанием переменных для наших окружений (для использования надо переименовать в `.env`):

- `microservices/compose_main/.env_main_example`
- `microservices/compose_infra/.env_infra_example`

#### Команды:

Для запуска наших получившихся окружений

- $ `docker stack deploy --compose-file=<(docker-compose -f compose_main/docker-compose.yml config 2>/dev/null) DEV` - запуск окружения для нашего основного приложения
- $ `docker stack deploy --compose-file=<(docker-compose -f compose_infra/docker-compose.yml config 2>/dev/null) DEV` - запуск окружения для мониторинга

Если мы хотим, чтобы приложение и мониторинг запускались в разных стеках (например **MAIN** и **INFRA**) и видели друг друга по сети, то предварительно надо создать используемые (**back_net** и **front_net**) overlay сети. Вместе с этим в `docker-compose.yml` в секции `networks` для каждой сети необходимо указать параметр `external: true`, то есть использовать уже существующую сеть. Такая конфигурация позволит нам независимо друг от друга деплоить и гасить разные стеки:

- $ `docker network create --driver=overlay --attachable back_net`
- $ `docker network create --driver=overlay --attachable front_net`
- $ `docker stack deploy --compose-file=<(docker-compose -f compose_main/docker-compose.yml config 2>/dev/null) MAIN`
- $ `docker stack deploy --compose-file=<(docker-compose -f compose_infra/docker-compose.yml config 2>/dev/null) INFRA`

# Homework 28 (branch kubernetes-1)

## Создание примитивов

> Опишем приложение в контексте Kubernetes с помощью manifest-ов<br>
> в YAML-формате. Основным примитивом будет Deployment.<br>
> Основные задачи сущности Deployment:<br>
> • Создание Replication Controller-а (следит, чтобы число<br>
> запущенных Pod-ов соответствовало описанному)<br>
> • Ведение истории версий запущенных Pod-ов (для различных<br>
> стратегий деплоя, для возможностей отката)<br>
> • Описание процесса деплоя (стратегия, параметры стратегий)<br>
> По ходу курса эти манифесты будут обновляться, а также<br>
> появляться новые. Текущие файлы нужны для создания<br>
> структуры и проверки работоспособности kubernetes-кластера.<br>

Файлы с Deployment манифестами приложений:

- `microservices/kubernetes/post-deployment.yml`
- `microservices/kubernetes/comment-deployment.yml`
- `microservices/kubernetes/ui-deployment.yml`
- `microservices/kubernetes/mongo-deployment.yml`

## [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

Результаты прохождения в директории `microservices/kubernetes/kubernetes_the_hard_way`

## Выполнение заания со звездочкой

- `microservices/kubernetes/kubernetes_the_hard_way/ansible/inventory` - настроен GCE Dynamic Inventory
- `microservices/kubernetes/kubernetes_the_hard_way/ansible/scripts` - действия из туториала в виде sh скриптов
- `microservices/kubernetes/kubernetes_the_hard_way/ansible/sertificats` - директория, куда буду попадать полученные в процессе выполенения туториала сертификаты
- `microservices/kubernetes/kubernetes_the_hard_way/ansible/main.yml` - запускает все используемые для туториала плайбуки.
- `microservices/kubernetes/kubernetes_the_hard_way/ansible/14-cleanup.yml` - удаление всего, что создано в процессе прохождения туториала.

Проверить:

- `kubectl apply -f mongo-deployment.yml`
- `kubectl apply -f post-deployment.yml`
- `kubectl apply -f comment-deployment.yml`
- `kubectl apply -f ui-deployment.yml`

# Homework 29 (branch kubernetes-2)

> Все ниже описанное, предполагает использование LINUX

## План

1. Развернуть локальное окружение для работы с Kubernetes
2. Развернуть Kubernetes в GKE
3. Запустить reddit в Kubernetes

### 1\. Развернуть локальное окружение для работы с Kubernetes

> Для дальнейшей работы нам нужно подготовить локальное окружение, которое будет состоять из:<br>

> - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - фактически, главной утилиты для работы c Kubernetes API (все, что делает kubectl,<br>
>   можно сделать с помощью HTTP-запросов > к API k8s)<br>

> - Директории ~>/.kube - содержит служебную инфу для kubectl (конфиги, кеши, схемы API)<br>

> - minikube - утилиты для разворачивания локальной инсталляции Kubernetes.<br>
>   (Для работы Minukube вам понадобится локальный гипервизор, например, [VirtualBox](https://www.virtualbox.org/wiki/Downloads))<br>
>   minikube устанавливается командой:<br>
>   `curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.23.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/`

#### Файлы:

`~/.kube/config` - хранит информацию о контекстах kubectl

#### Команды:

- $ `minikube start` - запусить наш миникластер

- $ `kubectl get nodes` - проверить, что Minikube-кластер развернут

  ```
  Порядок конфигурирования kubectl следующий:
  1) Создать cluster :
  $ kubectl config set-cluster ... cluster_name
  2) Создать данные пользователя (credentials)
  $ kubectl config set-credentials ... user_name
  3) Создать контекст
  $ kubectl config set-context context_name \
  --cluster=cluster_name \
  --user=user_name
  4) Использовать контекст
  $ kubectl config use-context context_name
  ```

> Таким образом kubectl конфигурируется для подключения к<br>
> разным кластерам, под разными пользователями.<br>

- $ `kubectl config current-context` - Текущий контекст

- $ `kubectl config get-contexts` - Список всех контекстов

#### 1.1 Запуск приложения

##### 1.1.1 UI, POST, COMMENT

> Для работы приложения в kubernetes, нам необходимо<br>
> описать его желаемое состояние либо в YAML-манифестах,<br>
> либо с помощью командной строки. Основные объекты - это<br>
> ресурсы **Deployment**.<br>

**Показано на примере UI. Post Comment - по аналогии**

###### Файлы:

- `microservices/kubernetes/ui-deployment.yml`
- `microservices/kubernetes/post-deployment.yml`
- `microservices/kubernetes/comment-deployment.yml`

###### Команды:

- $ `kubectl apply -f ui-deployment.yml` - Запустим в Minikube ui-компоненту

- $ `kubectl get deployment` - Убедимся, что во 2,3,4 и 5 столбцах стоит число 3 (число реплик ui)

> P.S. `kubectl apply -f <filename>`<br>
> может принимать не только отдельный файл, но и папку с ними.<br>
> Например:<br>
> `kubectl apply -f ./kube`<br>

> Пока что мы не можем использовать наше приложение<br>
> полностью, потому что никак не настроена сеть для общения с ним.<br>
> Но kubectl умеет пробрасывать сетевые порты POD-ов на локальную машину<br>
> Найдем используя selector POD-ы приложения<br>

> - $ `kubectl get pods --selector component=ui` -
> - $ `kubectl port-forward <pod-name> 8080:9292` - pod-name - любое имя POD,<br>
>   полученное в результате выполнения предыдущей команды.<br>

> Проверить, что UI работает, можно, зайдя в браузере на `http://localhost:8080`

```
$ kubectl apply -f post-deployment.yml
$ kubectl apply -f comment-deployment.yml
$ kubectl get pods --selector component=post
$ kubectl get pods --selector component=comment

Проверить, соответственно, для каждой из компонент:
$ kubectl port-forward <pod-name> 8080:5000 - для сервиса Post
$ kubectl port-forward <pod-name> 8080:9292 - для сервиса Comment
зайдя по адресу http://localhost:8080/healthcheck
```

> 5000 - это дефолт порт Python-фреймворка flask для веб-сервера, на нем написан Post<br>
> Comment написан на ruby-фреймворке, у которого 9292-дефолт порт<br>

##### 1.1.2 MongoDB

- `microservices/kubernetes/mongo-deployment.yml`

- $ `$ kubectl apply -f mongo-deployment.yml`

> Также примонтируем стандартный Volume для хранения данных вне контейнера (volumeMounts, volumes)

##### 1.1.3 Services

> В текущем состоянии приложение не будет работать, так его компоненты не ещё знают, как найти друг друга<br>
> Для связи компонент между собой и с внешним миром используется объект **Service** - абстракция, которая<br>
> определяет набор POD-ов (Endpoints) и способ доступа к ним<br>

###### Файлы:

- `microservices/kubernetes/post-service.yml`
- `microservices/kubernetes/comment-service.yml`
- `microservices/kubernetes/mongodb-service.yml`

###### Команды:

- $ `kubectl apply -f post-service.yml`
- $ `kubectl apply -f comment-service.yml`
- $ `kubectl apply -f mongodb-service.yml`
- $ `kubectl describe service post | grep Endpoints` - Посмотреть по label-ам соответствующие POD-ы
- $ `kubectl describe service comment | grep Endpoints`

Также изнутри любого POD должно разрешаться:

- $ `kubectl get pods --selector component=post`
- $ `kubectl get pods --selector component=comment`
- $ `kubectl exec -ti <pod-name> nslookup post` или
- $ `kubectl exec -ti <pod-name> ping post`
- $ `kubectl exec -ti <pod-name> ping comment` (nslookup в данном случае отрабатывать не будет, так как image Comment создан на основе ruby, не содержащей в себе команду `nslookup`)

> Если посмотреть логи, например, comment (`kubectl logs <comment-POD-name>`), то можно увиеть, что приложение ищет совсем другой адрес: comment_db, а не mongodb.<br>
> Аналогично и сервис post ищет post_db.<br>
> Эти адреса заданы в их Dockerfile-ах в виде переменных окружения:

> > post/Dockerfile<br>
> > ...<br>
> > ENV POST_DATABASE_HOST=post_db<br>

> > comment/Dockerfile<br>
> > ...<br>
> > ENV COMMENT_DATABASE_HOST=comment_db<br>

Решить эту проблему можно созданием еще одного сервиса сервиса для БД comment

- `comment-mongodb-service.yml`

> name: comment-db - так как в имени нельзя использовать знак подчеркиваниия<br>
> также добавим метку, чтобы различать сервисы и лейбл comment-db: "true"<br>

- $ `kubectl apply -f comment-mongodb-service.yml`

Обновим файл deployment для mongodb (mongo-deployment.yml), добавив `comment-db: "true"`, чтобы новый Service смог найти нужный POD

- $ `kubectl apply -f mongo-deployment.yml`

По аналогии - для сервиса Post:

- `post-mongodb-service.yml` - создали сервис для ДБ post
- `post-deployment.yml` - Зададим pod-ам post переменную окружения для обращения к базе
- `mongo-deployment.yml` - обновили, тобы новый Service post-db смог найти нужный POD

В результате сервис **mongodb** (файл mongodb-service.yml) стал не нужен. Можно его удалить.

- $ `kubectl delete -f mongodb-service.yml`<br>

или<br>

- $ `kubectl delete service mongodb`<br>

> Проверить работу приложения можно, пробросив порты на сервисе UI<br>
> kubectl port-forward **ui_pod-name** 8080:9292<br>

Организуем доступ к сервису UI снаружи:

- `ui-service.yml` - сервис для доступа к UI

> Теперь до сервиса можно дойти по Node-IP:NodePort<br>
> Node-IP можно узнать:<br>

> - $ `kubectl describe nodes`<br>

> NodePort - для доступа снаружи кластера<br>
> port - для доступа к сервису изнутри кластера<br>

#### 1.2 Minikube

- $ `minikube service ui` - выдать web-странцы с сервисами которые были помечены типом NodePort
- $ `minikube service list` - Посмотреть на список сервисов
- $ `minikube addons list` - получить список аддонов (расширений) для Kubernetes

##### 1.2.1 Namespace

> При старте Kubernetes кластер уже имеет 3 namespace:<br>
> • default - для объектов для которых не определен другой Namespace (в нем мы работали все это время)<br>
> • kube-system - для объектов созданных Kubernetes'ом и для управления им<br>
> • kube-public - для объектов к которым нужен доступ из любой точки кластера<br>

> Рассмотрим на примере аддон - dashboard:

- $ `minikube addons enable dashboard` - включить dashboard
- $ `kubectl get all -n kube-system --selector app=kubernetes-dashboard` - Найдем же объекты нашего dashboard

> Мы вывели все объекты из неймспейса kube-system, имеющие label app=kubernetes-dashboard

- $ `minikube service kubernetes-dashboard -n kube-system` - Зайдем в Dashboard

##### 1.2.2 Отделим среду для разработки приложения от всего остального кластера. (Namespace dev)

Создадим Namespace dev:

- `dev-namespace.yml`
- $ `kubectl apply -f dev-namespace.yml`
- `ui-deployment.yml` - добавили информацию об окружении DEV
- $ `kubectl apply -n dev -f .` - запусить приложение в DEV
- $ `minikube service ui -n dev` - посмотреть результат

### В GKE также можно запустить Dashboard для кластера.

- $ `kubectl create sa kubernetes-dashboard -n kube-system` - Добавим в систему Service Account для дашборда в namespace kube-system (там же запущен dashboard)
- $ `kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard` - назначим cluster-admin роль service account-у dashboard-а
- $ `kubectl proxy`
- `http://localhost:8001/ui`

## 2\. Развернуть Kubernetes в GKE

Пунк выполняется в GKE в вэб-интерфейсе

## 3\. Запустить reddit в Kubernetes в GKE

### Файлы:

YAML-манифсты разнес по соответствующим директориям:

- `microservices/kubernetes/app` - приложение
- `microservices/kubernetes/namespaces` - создание namespaces (в нашем случае создается namespace `dev`)

### Команды:

После создания кластера:

- $ `gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project infra-179710` - команда примерно такого вида для подключения к нашему кластеру (можно узнать команду в Kubernetes Engine -> Кластеры Kubenetes -> кнопка "Подключиться")
- $ `kubectl apply -f ./namespaces/` - создадим namespace `dev`
- $ `kubectl apply -f ./app/ -n dev` - поднимем наше приложение в созданном namespace `dev`

Наше приложение будет доступно по любому из EXTERNAL-IP Node (адрес можно узнать командой `kubectl get nodes -o wide`):

```
EXTERNAL-IP:32092    # Порт указан в `microservices/kubernetes/app/ui-service.yml` в параметре `nodePort`
```

## Задание со звездочкой

### 1\. Разверните Kubenetes-кластер в GKE с помощью [Terraform модуля](https://www.terraform.io/docs/providers/google/r/container_cluster.html)

- `microservices/kubernetes/terraform/main.tf`
- `microservices/kubernetes/terraform/create_cluster.tf`
- `microservices/kubernetes/terraform/variables.tf`
- `microservices/kubernetes/terraform/terraform.tfvars.example`
- `microservices/kubernetes/terraform/outputs.tf`
- $ `terraform init`
- $ `terraform plan`
- $ `terraform apply`
- $ `terraform destroy`

### 2\. Создайте YAML-манифесты для описания созданных сущностей для включения dashboard.

> Использовался [материал](https://github.com/kubernetes/dashboard/blob/master/src/deploy/alternative/kubernetes-dashboard.yaml)

- `microservices/kubernetes/dashboard/dashboard_service_account.yml`
- `microservices/kubernetes/dashboard/dashboard_cluster_role_binding(rbac).yml`
- `microservices/kubernetes/dashboard/dashboard-deployment.yml`
- `microservices/kubernetes/dashboard/dashboard_service.yml`
- $ `kubectl apply -f ./dashboard/`
- $ `kubectl proxy`
- $ `kubectl delete -f ./dashboard/`
