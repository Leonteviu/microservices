# microservices

**Посмотреть описание выполнения предыдущих домашних заданий можно** [здесь](readme_main.md).

# Homework 31 (branch kubernetes-4)

## План

- Работа с Helm
- Развертывание Gitlab в Kubernetes
- Запуск CI/CD конвейера в Kubernetes

## Helm

> Helm - пакетный менеджер для Kubernetes.<br>
> С его помощью мы будем:<br>
> 1) Стандартизировать поставку приложения в Kubernetes<br>
> 2) Декларировать инфраструктуру<br>
> 3) Деплоить новые версии приложения<br>

> Helm - клиент-серверное приложение.<br>

### Установим [Helm](https://github.com/kubernetes/helm/releases) (распакуйте и разместите исполняемый файл helm в директории исполнения (/usr/local/bin/ , /usr/bin, ...))

> Helm читает конфигурацию kubectl ( ~/.kube/config ) и сам<br>
> определяет текущий контекст (кластер, пользователь, неймспейс)<br>

```
Если хотите сменить кластер, то либо меняйте контекст с помощью
$ kubectl config set-context

либо подгружайте helm’у собственный config-файл флагом --kube-context .
```

### Установим серверную часть Helm'а - Tiller.

> Tiller - это аддон Kubernetes, т.е. Pod, который общается с API Kubernetes.<br>
> Для этого понадобится ему выдать **ServiceAccount**<br>
> и назначить роли **RBAC**, необходимые для работы.<br>

### Файлы:

- `~/microservices/kubernetes/tiller.yml`

### Команды:

- $ `terraform apply` - развернем кластер
- $ `gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project infra-179710` - подключемся к клстеру в [GCE](https://console.cloud.google.com/kubernetes) нажмем `подключиться` и скопируем ссылку
- $ `kubectl apply -f tiller.yml`
- $ `helm init --service-account tiller` - запустим tiller-сервер
- $ `kubectl get pods -n kube-system --selector app=helm` - проверим

**Важно! Убедитесь, что встроенный Ingress включен. (В [веб-консоли gcloud](https://console.cloud.google.com/kubernetes) должен быть включен "Балансировщик нагрузки HTTP").**

### Charts

> Chart - это пакет в Helm.<br>

```
Создадим директорию Charts в папке kubernetes со следующей структурой директорий:
|--Charts
   |-- comment
   |-- post
   |-- reddit
   |-- ui
```

#### Файлы:

**! helm предпочитает .yaml**

Разработка Chart'а для компоненты ui приложения

- `~/microservices/kubernetes/Charts/ui/Chart.yaml`

> Реально значимыми являются поля name и version. От них зависит<br>
> работа Helm'а с Chart'ом. Остальное - описания.

### Templates

> Основным содержимым Chart'ов являются шаблоны манифестов Kubernetes.

```
1) Создайте директорию ui/templates
2) Перенесите в неё все манифесты, разработанные ранее для
сервиса ui (ui-service, ui-deployment, ui-ingress)
3) Переименуйте их (уберите префикс “ui-“) и поменяйте
расширение на .yaml) - стилистические правки
|-- ui
    |-- Chart.yaml
    |-- templates
        |-- deployment.yaml
        |-- ingress.yaml
        |-- service.yaml

Получаем уже готовый пакет для установки в Kubernetes
```

#### Файлы:

Шаблонизируем Chart, чтобы можно было использовать его для запуска нескольких экземпляров (релизов).

- `~/microservices/kubernetes/Charts/ui/templates/service.yaml`

```
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-{{ .Chart.Name }}  # Нам нужно уникальное
  labels:                                      # имя запущенного ресурса
    app: reddit
    component: ui
    release: {{ .Release.Name }}   # Помечаем, что сервис из
spec:                              # конкретного релиза
  type: NodePort
  ports:
  - port: {{ .Values.service.externalPort }}
    protocol: TCP
    targetPort: {{ .Values.service.internalPort }}
  selector:
    app: reddit
    component: ui
    release: {{ .Release.Name }}  # Выбираем POD-ы только из этого релиза
```

```
name: {{ .Release.Name }}-{{ .Chart.Name }}

Здесь мы используем встроенные переменные
.Release - группа переменных с информацией о релизе
(конкретном запуске Chart’а в k8s)
.Chart - группа переменных с информацией о Chart’е (содержимое файла
Chart.yaml)

Также еще есть группы переменных:
.Template - информация о текущем шаблоне ( .Name и .BasePath)
.Capabilities - информация о Kubernetes (версия, версии API)
.Files.Get - получить содержимое файла
```

По аналогии шаблонизируем и остальные файлы сервиса UI

- `~/microservices/kubernetes/Charts/ui/templates/deployment.yaml`
- `~/microservices/kubernetes/Charts/ui/templates/ingress.yaml`
- `~/microservices/kubernetes/Charts/ui/values.yaml` - значения собственных переменных

> Обратить внимание, что в файле `ui/templates/ingress.yaml`<br>
> параметр - path: должен быть именно `/*` , иначе потом не будут<br>
> доступны страницы для создания новых постов <http://ingress-ip/new><br>
> (возникнет ошибка `default backend - 404`)<br>

Внесем изменения в файлы для Post:

- `~/microservices/kubernetes/Charts/post/templates/deployment.yaml`

```
Обратим внимание на адрес БД
Поскольку адрес БД может меняться в зависимости от условий запуска:
- БД отдельно от кластера
- БД запущено в отдельном релизе
- ...
, то создадим удобный шаблон для задания адреса БД:

env:
- name: POST_DATABASE_HOST
value: {{ .Values.databaseHost }}

Будем задавать БД через переменную databaseHost.
Иногда лучше использовать подобный формат переменных вместо
структур database.host, так как тогда прийдется определять
структуру database, иначе helm выдаст ошибку.
Используем функцию default. Если databaseHost не будет определена
или ее значение будет пустым, то используется вывод функции printf
(которая просто формирует строку <имя-релиза>-mongodb)
value: {{ .Values.databaseHost | default (printf "%s-mongodb" .Release.Name) }}

Теперь, если databaseHost не задано, то будет использовано
адрес базы, поднятой внутри релиза.
```

Более подробная [документация](https://docs.helm.sh/chart_template_guide/#the-chart-template-developer-s-guide) по шаблонизации и функциям

- `~/microservices/kubernetes/Charts/post/templates/service.yaml`
- `~/microservices/kubernetes/Charts/post/values.yaml` - значения собственных переменных

Внесем изменения в файлы для Coment:

- `~/microservices/kubernetes/Charts/comment/templates/deployment.yaml`
- `~/microservices/kubernetes/Charts/comment/templates/service.yaml`
- `~/microservices/kubernetes/Charts/comment/values.yaml` - значения собственных переменных

```
Также стоит отметить функционал Helm по использованию helper’ов и функции templates.
Helper - это написанная нами функция.
В функции описывается, как правило, сложная логика.
Шаблоны этих функций распологаются в файле _helpers.tpl

Пример функции comment.fullname :

charts/comment/templates/_helpers.tpl

{{- define "comment.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}
которая в результате выдаст то же, что и:
{{ .Release.Name }}-{{ .Chart.Name }}
```

```
Структура ипортирующей функции template {{ template "comment.fullname" . }}:

template             <- Функция template.

"comment.fullname"   <- Название функции для импорта.

.                    <- Область видимости для импорта.
                        “.”- вся область видимости всех переменных
                        (можно передать .Chart , тогда .Values
                        не будут доступны внутри функции)
```

#### Команды:

**Важно! Убедитесь, что встроенный Ingress включен. (В [веб-консоли gcloud](https://console.cloud.google.com/kubernetes) должен быть включен "Балансировщик нагрузки HTTP").**

> Убедитесь, что у вас не развернуты компоненты приложения в kubernetes. Если развернуты - удалите их

- $ `helm install --name test-ui-1 ui/` - установим Chart (здесь `test-ui-1` - имя релиза `ui/` - путь до Chart'a)
- $ `helm ls` - проверить

Установим несколько релизов

UI:

- $ `helm install ui --name ui-1`
- $ `helm install ui --name ui-2`
- $ `helm install ui --name ui-3`
- $ `kubectl get ingress` - проверим наличие трех Ingress

Comment:

- $ `helm install comment --name comment-1`
- $ `helm install comment --name comment-2`
- $ `helm install comment --name comment-3`

Post:

- $ `helm install comment --name post-1`
- $ `helm install comment --name post-2`
- $ `helm install comment --name post-3`

- $ `helm ls`

Можно обновить после внесения изменений:

- $ `helm upgrade ui-1 ui/`
- $ `helm upgrade ui-2 ui/`
- $ `helm upgrade ui-3 ui/`

Удалим все созданное:

- $ `helm del --purge ui-1`
- $ `helm del --purge ui-2`
- $ `helm del --purge ui-3`
- $ `helm del --purge post-1`
- $ `helm del --purge post-2`
- $ `helm del --purge post-3`
- $ `helm del --purge comment-1`
- $ `helm del --purge comment-2`
- $ `helm del --purge comment-3`

### Управление зависимостями

```
Мы создали Chart’ы для каждой компоненты нашего приложения.
Каждый из них можно запустить по-отдельности командой

$ helm install <chart-path> <release-name>

Но они будут запускаться в разных релизах, и не будут видеть
друг друга.

С помощью механизма управления зависимостями создадим
единый Chart reddit, который объединит наши компоненты
```

#### Файлы:

- `~/microservices/kubernetes/Charts/reddit/Chart.yaml` - Chart, объединяющий компоненты нашего приложения Reddit
- `~/microservices/kubernetes/Charts/reddit/values.yaml`
- `~/microservices/kubernetes/Charts/reddit/requirements.yaml`

```
dependencies:
  - name: ui                     <- Имя и версия должны совпадать
    version: "1.0.0"                с содеражанием ui/Chart.yml
    repository: file://../ui     <- Путь относительно расположения
  - name: post                      самого requiremetns.yml
    version: 1.0.0
    repository: file://../post
  - name: comment
    version: 1.0.0
    repository: file://../comment
    - name: mongodb                  Версия Chart для mongo из
      version: 0.4.20             <- общедоступного репозитория
      repository: https://kubernetes-charts.storage.googleapis.com
```

```
Есть проблема с тем, что UI-сервис не знает как правильно
ходить в post и comment сервисы.
Ведь их имена теперь динамические и зависят от имен чартов
В Dockerfile UI-сервиса уже заданы переменные окружения.
Надо, чтобы они указывали на нужные бекенды
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292
```

- `~/microservices/kubernetes/Charts/ui/templates/deployment.yaml`

```
Добавим в ui/templates/deployment.yaml:

- name: POST_SERVICE_HOST
  value: {{  .Values.postHost | default (printf "%s-post" .Release.Name) }}
- name: POST_SERVICE_PORT
  value: {{  .Values.postPort | default "5000" | quote }}
- name: COMMENT_SERVICE_HOST
  value: {{  .Values.commentHost | default (printf "%s-comment" .Release.Name) }}
- name: COMMENT_SERVICE_PORT
value: {{ .Values.commentPort | default "9292" | quote }}

Здесь quote - функция для добавления кавычек Для чисел и булевых значений это важно
```

- `~/microservices/kubernetes/Charts/ui/values.yaml`

```
Добавим в ui/values.yaml:

postHost:      # Можете даже закомментировать эти параметры или
postPort:      # оставить пустыми. Главное, чтобы они были в
commentHost:   # конфигурации Chart’а в качестве документации
commentPort:
```

- `~/microservices/kubernetes/Charts/reddit/values.yaml` - задавать переменные для зависимостей прямо в values.yaml самого Chart'а reddit (Они перезаписывают значения переменных из зависимых чартов).

#### Команды:

- $ `helm dep update` - загрузить зависимости (когда Chart' не упакован в tgz архив)

> В ~/microservices/kubernetes/Charts/reddit/<br>
> 1) Появится файл requirements.lock с фиксацией зависимостей<br>
> 2) Будет создана директория charts с зависимостями в виде архивов<br>

- $ `helm search mongo` - найдем Chart для **mongo** в общедоступном окружении (Chart для базы данных не будем создавать вручную. Возьмем готовый)

- $ `helm dep update reddit` - загрузим зависимости для Reddit (загрузится необходимый Chart для mongodb)

- $ `helm install reddit --name reddit-test` - **запустим наше приложение релиз `reddit-test`**

- $ `kubectl get ingress` - узнаем IP для подключения к нашему приложению

- $ `helm dep update ./reddit` - После обновления UI - нужно обновить зависимости чарта reddit.

- $ `helm upgrade reddit-test ./reddit` - Обновите релиз, установленный в k8s

## Развертывание Gitlab в Kubernetes

```
Необходимо:

$ terraform apply - поднимем кластер
$ gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project infra-179710 - подключимся к кластеру

Добавим в настройки нашего кластера новый пул узлов:
- назовите его bigpool
- 1 узел типа n2-standard (7,5 Гб, 2 виртуальных ЦП)
- Размер диска 20-40 Гб
Отключите RBAC для упрощения работы (Gitlab-Omnibus пока не
подготовлен для этого, а самим это в рамках работы смысла
делать нет).

$ kubectl apply -f tiller.yml

$ helm init --service-account tiller - запустим tiller-сервер
```

### 1\. Установим Gitlab

### Файлы

Откорректируем файлы

- `gitlab-omnibus/values.yaml`
- `gitlab-omnibus/templates/gitlab/gitlab-svc.yaml`
- `gitlab-omnibus/templates/ingress/gitlab-ingress.yaml`

### Команды

Gitlab будем ставить также с помощью Helm Chart'а из пакета Omnibus.

- $ `helm repo add gitlab https://charts.gitlab.io` - Добавим репозиторий Gitlab
- $ `helm fetch gitlab/gitlab-omnibus --version 0.1.36 --untar` - Мы будем менять конфигурацию Gitlab, поэтому скачаем Chart
- $ `cd gitlab-omnibus`

После корректировки файлов:

- $ `helm install --name gitlab . -f values.yaml`
- $ `kubectl get service -n nginx-ingress nginx` - Найти выданный EXTERNAL-IP-адрес ingress-контроллера nginx
- $ `echo "<EXTERNAL-IP> gitlab-gitlab staging production leonteviu-ui-feature-3” >> /etc/hosts` - Поместите запись в локальный файл /etc/hosts (поставьте свой IP-адрес)
- $ `kubectl get pods` - проверить, что gitlab поднялся

> Теперь можно зайти по адерсу <http://gitlab-gitlab>

### 2\. Запустим проект

Действия выполняются в WEB-интерфейсе по адресу <http://gitlab-gitlab>

- Создать новую группу
- Имя новой группы - свой Docker ID
- Visibility Level - Public
- Create a Mattermost team for this group - убрать галочку
- В настройках группы выберите пункт CI/CD. Добавьте 2 переменные - CI_REGISTRY_USER - логин в dockerhub CI_REGISTRY_PASSWORD - пароль от Docker Hub

  > Эти учетные данные будут использованы при сборке и<br>
  > релизе docker-образов с помощью Gitlab CI<br>

- В группе создадим проекты 'reddit-deploy', post, ui и comment (сделайте также публичными)

--------------------------------------------------------------------------------

**Описанные ниже действия не вошли в коммиты**

- Локально у себя создайте:
- `Gitlab_ci/comment`
- `Gitlab_ci/post`
- `Gitlab_ci/ui`
- `Gitlab_ci/reddit-deploy`

- Перенесите исходные коды сервиса ui в Gitlab_ci/ui (post, comment - соответственно)

- В директории Gitlab_ci/ui:

- $ `git init` - Инициализируем локальный git-репозиторий

- $ `git remote add origin http://gitlab-gitlab/leonteviu/ui.git`

- $ `git add .`

- $ `git commit -m “init”`

- $ `git push origin master`

> Для post и comment продейлайте аналогичные действия.<br>
> Не забудьте указывать соответствующие названия<br>
> репозиториев и групп.<br>

- Перенести содержимое директории Charts (папки ui, post,comment, reddit) в Gitlab_ci/reddit-deploy

- Запушить reddit-deploy в gitlab-проект reddit-deploy (команды аналогичные ui)

- Создайте файл [Gitlab_ci/ui/.gitlab-ci.yml](HomeWorks_files/HW_31/doc_page_71/.gitlab-ci.yml)

- Закомитьте и запуште в gitlab

- Проверьте, что Pipeline работает

- Создайте файл [Gitlab_ci/ui/.gitlab-ci.yml](HomeWorks_files/HW_31/doc_page_72/.gitlab-ci.yml)

- Закомитьте и запуште в gitlab

- Проверьте, что Pipeline работает

  > В текущей конфигурации CI выполняет<br>
  > 1) Build: Сборку докер-образа с тегом master<br>
  > 2) Test: Фиктивное тестирование<br>
  > 3) Release: Смену тега с master на тег из файла VERSION и<br>
  > пуш docker-образа с новым<br>
  > Job для выполнения каждой задачи запускается в отдельном<br>
  > Kubernetes POD-е.<br>

**! Для Post и Comment также добавьте в репозиторий .gitlab-ci.yml и проследите, что сборки образов прошли успешно.**

- Дадим возможность разработчику запускать отдельное окружение в Kubernetes по коммиту в feature-бранч. Немного обновим конфиг ингресса для сервиса UI:

[reddit-deploy/ui/templates/ingress.yml](HomeWorks_files/HW_31/doc_page_76/ingress.yml)

> Здесь в качестве контроллера используется NGINX, поэтому `path: /` - отличие от ДЗ 30

- Немного обновим конфиг ингресса для сервиса UI: [reddit-deploy/ui/templates/values.yml](HomeWorks_files/HW_31/doc_page_77/values.yml)

- Дадим возможность разработчику запускать отдельное окружение в Kubernetes по коммиту в feature-бранч:

- $ `git checkout -b feature/3`

- Обновим [ui/.gitlab-ci.yml](HomeWorks_files/HW_31/doc_page_78/.gitlab-ci.yml) файл

- $ `git commit -am "Add review feature"`

- $ `git push origin feature/3`

> В коммитах ветки feature/3 можете найти сделанные изменения<br>
> Отметим, что мы добавили стадию review, запускающую<br>
> приложение в k8s по коммиту в feature-бранчи (не master).<br>

> Мы добавили функцию deploy, которая загружает Chart из репозитория<br>
> reddit-deploy и делает релиз в неймспейсе review с образом<br>
> приложения, собранным на стадии build.<br>

- $ `helm ls` - Можем увидеть какие релизы запущены

Созданные для таких целей окружения временны, их требуется "убивать", когда они больше не нужны.

- Добавьте в [ui/.gitlab-ci.yml](HomeWorks_files/HW_31/doc_page_82/.gitlab-ci.yml):<br>
  `stop_review` - stage<br>
  `- cleanup` - строка<br>
  `on_stop: stop_review` - строка<br>
  `function delete()` - функцию удаления<br>

- Запуште изменения в Git

- зайдите в Pipelines ветки feature/3 (В Environments можно вызвать полученную web-страницу. ее алиас занесен в /etc/hosts ранее)

- Запустить удаление окружения.

- $ `helm ls` - окружения feature/3 быть не должно

> Скопировать полученный файл .gitlab-ci.yml для ui в<br>
> репозитории для post и comment.<br>
> Проверить, что динамическое создание и удаление окружений<br>
> работает и с ними как ожидалось<br>

Теперь создадим staging и production среды для работы приложения.

- Создайте файл [reddit-deploy/.gitlab-ci.yml](HomeWorks_files/HW_31/doc_page_88/.gitlab-ci.yml)
- Запуште в репозиторий reddit-deploy ветку master

> Этот файл отличается от предыдущих тем, что:<br>
> 1) Не собирает docker-образы<br>
> 2) Деплоит на статичные окружения (staging и production)<br>
> 3) Не удаляет окружения<br>

- Удостоверьтесь, что staging успешно завершен
- В Environments найдите staging
- Выкатываем на production И ждем пока пайплайн пройдет

- $ `helm ls`

--------------------------------------------------------------------------------

```
Файлы .gitlab-ci.yml, полученные в ходе работы,
поместите в папку с исходниками для каждой компоненты приложения.
Файл .gitlab-ci.yml для reddit-deploy поместите в charts
Все изменения, которые были внесены в Chart’ы - перенести в
папку charts, созданную вначале.
```

--------------------------------------------------------------------------------

## Задание со звездочкой

[.gitlab-ci.yml](HomeWorks_files/HW_31/zvezdochka/.gitlab-ci.yml) нужно поместить в репозитории UI, POST и COMMENT (в Gitlab_ci директории). При любом изменении исходного кода сервисов, необходимо внести также изменение в содержимое файла VERSION в исходном коде (например увеличить версию) и запушить в Gitlab.

--------------------------------------------------------------------------------
