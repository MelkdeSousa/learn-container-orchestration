#!/bin/bash
ENV_LABEL=${1:-"dev"}
NUM_MANAGERS=${2:-1}
NUM_WORKERS=${3:-2}

VM_CPU=1
VM_MEM="1G"
VM_DISK="5G"
for i in $(seq 1 $NUM_MANAGERS); do
    multipass launch --name "swarm-mgr-$ENV_LABEL-$i" --cpus $VM_CPU --memory $VM_MEM --disk $VM_DISK
done
for i in $(seq 1 $NUM_WORKERS); do
    multipass launch --name "swarm-wrk-$ENV_LABEL-$i" --cpus $VM_CPU --memory $VM_MEM --disk $VM_DISK
done
ALL_VMS=$(multipass list | grep "$ENV_LABEL" | awk '{print $1}')
for vm in $ALL_VMS; do
    multipass exec $vm -- bash -c "curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker ubuntu" &
done
wait
FIRST_MGR="swarm-mgr-$ENV_LABEL-1"
MGR_IP=$(multipass exec $FIRST_MGR -- hostname -I | awk '{print $1}')
if [ -z "$MGR_IP" ]; then
    echo "❌ Erro: Não foi possível capturar o IP do Manager."
    exit 1
fi
multipass exec $FIRST_MGR -- docker swarm leave --force 2>/dev/null
multipass exec $FIRST_MGR -- docker swarm init --advertise-addr $MGR_IP
WORKER_TOKEN=$(multipass exec $FIRST_MGR -- docker swarm join-token worker -q)
MANAGER_TOKEN=$(multipass exec $FIRST_MGR -- docker swarm join-token manager -q)
if [ $NUM_MANAGERS -gt 1 ]; then
    for i in $(seq 2 $NUM_MANAGERS); do
        MGR_NAME="swarm-mgr-$ENV_LABEL-$i"
        multipass exec $MGR_NAME -- docker swarm join --token $MANAGER_TOKEN $MGR_IP:2377
    done
fi
for i in $(seq 1 $NUM_WORKERS); do
    WRK_NAME="swarm-wrk-$ENV_LABEL-$i"
    multipass exec $WRK_NAME -- docker swarm join --token $WORKER_TOKEN $MGR_IP:2377
    multipass exec $FIRST_MGR -- docker node update --label-add env=$ENV_LABEL $WRK_NAME
done
multipass exec $FIRST_MGR -- docker node ls
