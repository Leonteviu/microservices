# 1\. Поднять кластер:

- $ `./terraform terraform apply`

# 2\. Подключимся к кластеру (Смотрим команду в [GCE](https://console.cloud.google.com/kubernetes)). Команда должна выглядеть примерно так:

- $ `gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project infra-179710`

# 3\. Создадим окружение `DEV`

- $ `kubectl apply -f ./namespaces/dev-namespace.yml`

# 3\. Создадим два StorageClass для выделения Volume в динамическом режиме (будем использовать только медленные диски `storage-fast.yml`)

- $ `kubectl apply -f ./app/storage-slow.yml -n dev`
- $ `kubectl apply -f ./app/storage-fast.yml -n dev`
- $ `kubectl apply -f ./app/mongo-claim-dynamic.yml -n dev`
- $ `kubectl get persistentvolume -n dev` - можно посмотреть на созданные диски

# 4\. Поднимем наше приложение

- $ `kubectl apply -f ./app/mongo-deployment.yml -n dev`
- $ `kubectl apply -f ./app/comment-deployment.yml -n dev`
- $ `kubectl apply -f ./app/comment-mongodb-service.yml -n dev`
- $ `kubectl apply -f ./app/comment-service.yml -n dev`
- $ `kubectl apply -f ./app/post-deployment.yml -n dev`
- $ `kubectl apply -f ./app/post-mongodb-service.yml -n dev`
- $ `kubectl apply -f ./app/post-service.yml -n dev`
- $ `kubectl apply -f ./app/ui-deployment.yml -n dev`
- $ `kubectl apply -f ./app/ui-service.yml -n dev`

# 5\. Подготовим сертификат TLS, и загрузим его в кластер kubernetes

- $ `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=12345"`
- $ `kubectl apply -f ./secret/ui-secret.yml -n dev` (либо командой `kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev`)
- $ `kubectl describe secret ui-ingress -n dev` - можно проверить

# 6\. Ingress Controller разрешим только HTTPS

- $ `kubectl apply -f ./app/ui-ingress.yml -n dev`

# 7\. Network Policy

- $ `gcloud beta container clusters list` - узнаем имя кластера
- $ `gcloud beta container clusters update <cluster-name> --zone=us-central1-a --update-addons=NetworkPolicy=ENABLED`
- $ `gcloud beta container clusters update <cluster-name> --zone=us-central1-a --enable-network-policy`

> Может быть предложено добавить beta-функционал в gcloud - нажмите yes.

- $ `kubectl apply -f ./app/mongo-network-policy.yml -n dev`
