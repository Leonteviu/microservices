#!/bin/sh
#
cd sertificats
#The Admin Client Certificate
#
#Copy the appropriate certificates and private keys to each worker instance:
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done
#
#Copy the appropriate certificates and private keys to each controller instance:
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem ${instance}:~/
done
