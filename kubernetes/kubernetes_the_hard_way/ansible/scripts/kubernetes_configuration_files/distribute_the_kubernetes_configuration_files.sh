#!/bin/sh
#
cd sertificats
#
#Copy the appropriate kubelet and kube-proxy kubeconfig files to each worker instance:
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
