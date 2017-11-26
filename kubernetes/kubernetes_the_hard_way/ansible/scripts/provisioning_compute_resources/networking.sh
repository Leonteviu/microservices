#!/bin/sh
#
#Preparing
#
#gcloud config set compute/region us-west1
#
#Set a default compute zone:
#
#gcloud config set compute/zone us-west1-c

# Virtual Private Cloud Network
#
#Create the kubernetes-the-hard-way custom VPC network:
gcloud compute networks create kubernetes-the-hard-way --mode custom
#
#Create the kubernetes subnet in the kubernetes-the-hard-way VPC network:
gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-hard-way \
  --range 10.240.0.0/24
#
#Firewall Rules
#
#Create a firewall rule that allows internal communication across all protocols:
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16
#
#Create a firewall rule that allows external SSH, ICMP, and HTTPS:
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
#
#Kubernetes Public IP Address
#
#Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:
gcloud compute addresses create kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region)
