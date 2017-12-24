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
