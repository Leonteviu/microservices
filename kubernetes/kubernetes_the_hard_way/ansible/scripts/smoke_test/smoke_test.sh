#!/bin/sh
#
#Data Encryption
#
#Create a generic secret:
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

#Print a hexdump of the kubernetes-the-hard-way secret stored in etcd:
#
#gcloud compute ssh controller-0 \
#  --command "ETCDCTL_API=3 etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
#
#Deployments
#
#Create a deployment for the nginx web server:
kubectl run nginx --image=nginx
#
#List the pod created by the nginx deployment:
#kubectl get pods -l run=nginx
#
#Port Forwarding
#
#Retrieve the full name of the nginx pod:
#POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
#
#Forward port 8080 on your local machine to port 80 of the nginx pod:
#kubectl port-forward $POD_NAME 8080:80
#
#In a new terminal make an HTTP request using the forwarding address:
#curl --head http://127.0.0.1:8080
#
#Logs
#
#Print the nginx pod logs:
#kubectl logs $POD_NAME
#
#Exec
#Print the nginx version by executing the nginx -v command in the nginx container:
#kubectl exec -ti $POD_NAME -- nginx -v
#
#Services
#
#Expose the nginx deployment using a NodePort service:
kubectl expose deployment nginx --port 80 --type NodePort
#
#Retrieve the node port assigned to the nginx service:
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
#
#Create a firewall rule that allows remote access to the nginx node port:
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
  --allow=tcp:${NODE_PORT} \
  --network kubernetes-the-hard-way
#
#Retrieve the external IP address of a worker instance:
EXTERNAL_IP=$(gcloud compute instances describe worker-0 \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
#
#Make an HTTP request using the external IP address and the nginx node port:
#curl -I http://${EXTERNAL_IP}:${NODE_PORT}
