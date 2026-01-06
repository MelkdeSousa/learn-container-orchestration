#!/bin/bash
CLUSTER_NAME="k0s-local"
WORKERS=2
RAM="2G"
CPU="2"
DISK="5G"
multipass launch --name "${CLUSTER_NAME}-controller" --cpus $CPU --memory $RAM --disk $DISK
multipass exec "${CLUSTER_NAME}-controller" -- sh -c "curl --proto '=https' --tlsv1.2 -sSf https://get.k0s.sh | sudo sh"
multipass exec "${CLUSTER_NAME}-controller" -- sudo k0s install controller --enable-worker --no-taints
multipass exec "${CLUSTER_NAME}-controller" -- sudo k0s start
sleep 20
multipass exec "${CLUSTER_NAME}-controller" -- sh -c "sudo k0s token create --role=worker > /tmp/k0s-token"
multipass transfer "${CLUSTER_NAME}-controller":/tmp/k0s-token /tmp/k0s-token
for i in $(seq 1 $WORKERS); do
    multipass launch --name "${CLUSTER_NAME}-worker-$i" --cpus $CPU --memory $RAM --disk $DISK
    multipass transfer /tmp/k0s-token "${CLUSTER_NAME}-worker-$i":/tmp/k0s-token
    multipass exec "${CLUSTER_NAME}-worker-$i" -- sh -c "curl -sSLf https://get.k0s.sh | sudo sh"
    multipass exec "${CLUSTER_NAME}-worker-$i" -- sudo k0s install worker --token-file /tmp/k0s-token
    multipass exec "${CLUSTER_NAME}-worker-$i" -- sudo k0s start
done
sleep 20
multipass exec "${CLUSTER_NAME}-controller" -- sudo k0s kubectl get nodes
