#!/bin/sh
#
cd sertificats
#The Admin Kubernetes Configuration File
#
#Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.
#
#Retrieve the kubernetes-the-hard-way static IP address:
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
#
#Generate a kubeconfig file suitable for authenticating as the admin user:
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443
#
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem
#
kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin
#
kubectl config use-context kubernetes-the-hard-way
