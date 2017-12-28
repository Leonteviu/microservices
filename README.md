# microservices

**Посмотреть описание выполнения предыдущих домашних заданий можно** [здесь](readme_main.md).

# Homework 32 (branch kubernetes-5)

```
У вас должен быть развернуть кластер k8s:
- минимум 2 ноды g1-small (1,5 ГБ)
- минимум 1 нода n1-standard-2 (7,5 ГБ)
В настройках:
- Stackdriver Logging - Отключен
- Stackdriver Monitoring - Отключен
- Устаревшие права доступа - Включено

$ terraform apply - развернем кластер
$ gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project infra-179710 - подключемся к клстеру в [GCE](https://console.cloud.google.com/kubernetes) нажмем `подключиться` и скопируем ссылку
$ kubectl apply -f tiller.yml
$ helm init --service-account tiller - запустим tiller-сервер
$ kubectl get pods -n kube-system --selector app=helm - проверим

$ helm install stable/nginx-ingress --name nginx - Из Helm-чарта установим ingress-контроллер nginx
$ kubectl get svc - Найдите <EXTERNAL-IP>, выданный nginx’у

Добавьте в /etc/hosts строку:
<EXTERNAL-IP> reddit reddit-prometheus reddit-grafana reddit-non-prod production reddit-kibana prod
```

## План

- Развертывание Prometheus в k8s
- Настройка Prometheus и Grafana для сбора метрик
- Настройка EFK для сбора логов

## Мониторинг

```
Будем использовать следующие инструменты:
- prometheus - сервер сбора и
- grafana - сервер визуализации метрик
- alertmanager - компонент prometheus для алертинга
- различные экспортеры для метрик prometheus
Prometheus отлично подходит для работы с контейнерами и
динамичным размещением сервисов
```

### Установка Prometheus (release 2.0)

> Prometheus будем ставить с помощью Helm чарта<br>
> Скачаем этот Chart отдельно.<br>

- $ `git clone https://github.com/kubernetes/charts.git kube-charts` - Склонируем репозиторий с чартами
- $ `cd kube-charts`
- $ `git fetch origin pull/2767/head:prom_2.0`
- $ `git checkout prom_2.0` - Переключимся на ветку с этим PR
- $ `cp -r kube-charts/stable/prometheus <директория kubernetes/charts>` - Переместим чарт c prometheus в нашу директорию charts
- $ `rm -rf kube-charts` - удалим скачанный репозиторий
- $ `cd charts/prometheus`

#### Файлы:

- `kubernetes/Charts/prometheus/custom_values.yml`

> Основные отличия от values.yml:<br>
> • отключена часть устанавливаемых сервисов<br>
> (pushgateway, alertmanager, kube-state-metrics)<br>
> • включено создание Ingress'а для подключения через nginx<br>
> • поправлен endpoint для сбора метрик cadvisor<br>
> • уменьшен интервал сбора метрик (с 1 минуты до 30 секунд)<br>

- $ `helm upgrade prom . -f custom_values.yml --install` - Запустите Prometheus в k8s

#### Targets

> Таргеты для сбора метрик найдены с помощью service discovery (SD),<br>
> настроенного в конфиге prometheus (лежит в custom_values.yml)<br>

```
prometheus.yml:
...
- job_name: 'kubernetes-apiservers'
...
- job_name: 'kubernetes-nodes'
  kubernetes_sd_configs:              Настройки Service Discovery
    - role: node                      (для поиска target’ов)


  scheme: https                        Настройки подключения к target’ам
  tls_config:                          (для сбора метрик)
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token


relabel_configs:                 Настройки различных меток,
                                 фильтрация найденных таргетов, их изменение
...
```

Использование SD в kubernetes позволяет нам динамично менять кластер (как сами хосты, так и сервисы и приложения) Цели для мониторинга находим c помощью запросов к k8s API:

```
prometheus.yml:
...
  scrape_configs:
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
        - role: node

        Role
        объект, который нужно найти:
        • node
        • endpoints
        • pod
        • service
        • ingress
```

```
...
scrape_configs:
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
```

> Т.к. сбор метрик prometheus осуществляется поверх<br>
> стандартного HTTP-протокола, то могут понадобится доп.<br>
> настройки для безопасного доступа к метрикам.<br>
> Ниже приведены настройки для сбора метрик из k8s API.<br>

```
scheme: https
tls_config:
  ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  insecure_skip_verify: true
bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

Здесь
1) Схема подключения - http (default) или https
2) Конфиг TLS - коревой сертификат сервера для проверки достоверности сервера
3) Токен для аутентификации на сервере
```

```
relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: kubernetes.default.svc:443
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

Здесь
1) преобразовать все k8s лейблы таргета в лейблы prometheus
2) Поменять лейбл для адреса сбора метрик
3) Поменять лейбл для пути сбора метрик
```

> Подробнее о том, как работает [relabel_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Crelabel_config%3E)

Все найденные на эндпоинтах метрики сразу же отобразятся в списке (вкладка Graph). Метрики Cadvisor начинаются с container_.

Cadvisor собирает лишь информацию о потреблении ресурсов и производительности отдельных docker-контейнеров. При этом он ничего не знает о сущностях k8s (деплойменты, репликасеты, ...).

Для сбора этой информации будем использовать сервис [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics). Он входит в чарт Prometheus. Включим его.

- `prometheus/custom_values.yml`

```
kubeStateMetrics:
  ## If false, kube-state-metrics will not be installed
  ##
  enabled: true
```

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install` - Обновим релиз

По аналогии включим `nodeExporter`

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install` - Обновим релиз

#### Метрики приложений

**Для продолжения выполнения убедиться, что проделаны [следующие действия](https://github.com/Leonteviu/microservices#%D0%9A%D0%BE%D0%BC%D0%B0%D0%BD%D0%B4%D1%8B-2) должен присустствовать kubernetes/Charts/reddit/requirements.lock и создана директория charts с зависимостями в виде архивов comment-1.0.0.tgz, mongodb-0.4.20.tgz, post-1.0.0.tgz и ui-1.0.0.tgz**

Запустите приложение из helm чарта reddit:

- $ `helm upgrade reddit-test ./reddit --install`
- $ `helm upgrade production --namespace production ./reddit --install`
- $ `helm upgrade staging --namespace staging ./reddit --install`

Раньше мы "хардкодили" адреса/dns-имена наших приложений для сбора метрик с них.

```
prometheus.yml

- job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'

- job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'
```

Теперь мы можем использовать механизм ServiceDiscovery для обнаружения приложений, запущенных в k8s.

Приложения будем искать так же, как и служебные сервисы k8s.

Внесем изменения в конфиг Prometheus:

```
custom_values.yml

- job_name: 'reddit-endpoints'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_app]
        action: keep              <--- Используем действие keep, чтобы оставить
        regex: reddit                  только эндпоинты сервисов с метками
                                       “app=reddit”
```

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`

Мы получили эндпоинты, но что это за поды мы не знаем. Добавим метки k8s

Все лейблы и аннотации k8s изначально отображаются в prometheus в формате:

```
__meta_kubernetes_service_label_labelname
__meta_kubernetes_service_annotation_annotationname
```

custom_values.yml:

```
- job_name: 'reddit-endpoints'
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
  #  - source_labels: [__meta_kubernetes_service_label_app]
  #    action: keep
  #    regex: reddit
    - action: labelmap                            <-- Отобразить все совпадения групп из regex
      regex: __meta_kubernetes_service_label_(.+)     в label’ы Prometheus
```

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`

Теперь мы должны увидеть лейблы k8s, присвоенные POD'ам

Добавим еще label'ы для prometheus и обновим helm-релиз. Т.к. метки вида `__meta_*` не публикуются, то нужно создать свои, перенеся в них информацию

custom_values.yml:

```
- job_name: 'reddit-endpoints'
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
  #  - source_labels: [__meta_kubernetes_service_label_app]
  #    action: keep
  #    regex: reddit
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      target_label: kubernetes_name
```

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`

Сейчас мы собираем метрики со всех сервисов reddit'а в 1 группе target-ов. Мы можем отделить target-ы компонент друг от друга (по окружениям, по самим компонентам), а также выключать и включать опцию мониторинга для них с помощью все тех же label-ов. Например, добавим в конфиг еще 1 job:

```
- job_name: 'reddit-production'
   kubernetes_sd_configs:
     - role: endpoints
   relabel_configs:
     - action: labelmap
       regex: __meta_kubernetes_service_label_(.+)
     - source_labels: [__meta_kubernetes_service_label_app, __meta_kubernetes_namespace]
       action: keep
       regex: reddit;(production)+                   <--------PRODUCTION
     - source_labels: [__meta_kubernetes_namespace]
       target_label: kubernetes_namespace
     - source_labels: [__meta_kubernetes_service_name]
       target_label: kubernetes_name

Здесь:

__meta_kubernetes_namespace   <--- Для разных лейблов
(production|staging)+         <--- разные regex
```

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`

По аналогии создадим и `job_name: 'reddit-staging'` для окружения staging

> Если есть необходимость вывести для production и staging одновременно, то `regex: reddit;(production|staging)+`

Разобьем конфигурацию job'а `reddit-endpoints` так,чтобы было 3 job'а для каждой из компонент приложений (post-endpoints, comment-endpoints, ui-endpoints), а reddit-endpoints уберем.

Пример для `- job_name: 'ui-endpoints'`:

```
- job_name: 'ui-endpoints'
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_label_app, __meta_kubernetes_service_label_component]
      action: keep
      regex: reddit;(ui)+
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      target_label: kubernetes_name
```

### Визуализация

Поставим **Grafana** с помощью helm:

```
helm upgrade --install grafana stable/grafana --set "server.adminPassword=admin" \
--set "server.service.type=NodePort" \
--set "server.ingress.enabled=true" \
--set "server.ingress.hosts={reddit-grafana}"
```

Немного подожде и перейдем по адресу <http://reddit-grafana> (логин: admin пароль: admin)

Добавим самый распространенный [dashboard](https://grafana.com/dashboards/315) для отслеживания состояния ресурсов k8s

Также можно добавить свои ранее созданные[dashboards](https://github.com/Leonteviu/microservices/tree/master/dashboards)

#### Templating

В текущий момент на графиках, относящихся к приложению, одновременно отображены значения метрик со всех источников сразу. При большом количестве сред и при их динамичном изменении имеет смысл сделать динамичной и удобно настройку наших дашбордов в Grafana. Сделать это можно в нашем случае с помощью механизма templating'а.

> Настройка просиходит в графическом интерфейсе

#### Смешанные графики

На этом [графике](https://grafana.com/dashboards/741) одновременно используются метрики и шаблоны из cAdvisor, и из kube-state-metrics для отображения сводной информации по деплойментам

--------------------------------------------------------------------------------

## Задание со звездочкой (запустить alertmanager в k8s и настроить правила для контроля за доступностью api-сервера и хостов k8s):

### 1\. Запустим alertmanager в k8s

Внесем изменения в Charts/prometheus/custom_values.yml:

```
alertmanager:
  ## If false, alertmanager will not be installed
  ##
  enabled: true                    <---
...
  ingress:
    ## If true, alertmanager Ingress will be created
    ##
    enabled: true   <-- сможем видеть Alertmanager по адресу http://prometheus-alertmanager (параметр hosts)
...
    hosts:
      - prometheus-alertmanager
```

Не забудем внести `prometheus-alertmanager` в файл `/etc/hosts`

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`

### 2\. Настроим правила для контроля за доступностью api-сервера и хостов k8s

Правила слертинга будем записывать внутри custom_values.yml. Не забываем, что [формат описания правил в Prometheus версии 2.0 изменился на yaml](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

Внесем изменения в модуль `serverFiles:` в Chart:s/prometheus/custom_values.yml:

```
serverFiles:
  alerts: {}
  rules: {}
```

> В <http://prometheus-alertmanager> введем метрику UP и найдем интересующие нас job<br>
> kubernetes-apiservers и kubernetes-nodes

```
serverFiles:
  alerts:
    groups:
    - name: Available k8s API-server and Nodes
      rules:

  # Alert for any instance that is unreachable for >5 minutes.
      - alert: k8s API-server NOT unreachable
        expr: up{job="kubernetes-apiservers"} == 0
        for: 1m
        labels:
          severity: page
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."

  # Alert for any Node that is unreachable for >1 minutes.
      - alert: Node NOT unreachable
        expr: up{job="kubernetes-nodes"} == 0
        for: 1m
        labels:
          severity: page
        annotations:
          summary: "Node {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."

  rules: {}
```

Обновим релиз prometheus:

- $ `helm upgrade prom ./prometheus -f custom_values.yml --install`
