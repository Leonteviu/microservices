#!/bin/bash

git clone git@github.com:dcu/mongodb_exporter.git ~/microservices/mongodb_exporter
cd ~/microservices/mongodb_exporter
docker build -t $USERNAME/mongodb-exporter .
cd ..
rm -rf ~/microservices/mongodb_exporter
