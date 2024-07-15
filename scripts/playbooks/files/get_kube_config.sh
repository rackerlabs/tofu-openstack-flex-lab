#!/usr/bin/env bash
# Simple script to run from launcher node to get the kube config from the kubernetes node
IP_ADDRESS=$(getent hosts  kubernetes01 | awk '{print $1}')
rsync -avz -e 'ssh -o StrictHostKeyChecking=no' --rsync-path="sudo rsync" kubernetes01:/root/.kube $HOME/
sed -i "s/127.0.0.1/$IP_ADDRESS/g" $HOME/.kube/config