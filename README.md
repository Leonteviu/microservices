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
