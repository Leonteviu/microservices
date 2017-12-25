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
