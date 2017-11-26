#!/bin/sh
#
#Deploy the kube-dns cluster add-on:
#
kubectl create -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
#Create a busybox deployment:
kubectl run busybox --image=busybox --command -- sleep 3600
