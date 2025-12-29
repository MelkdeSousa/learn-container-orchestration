#!/bin/bash

# Configurações Padrão
ENV_LABEL=${1:-"dev"}
NUM_MANAGERS=${2:-1}
NUM_WORKERS=${3:-2}

VM_CPU=1
VM_MEM="1G"
VM_DISK="5G"

echo "🚀 Iniciando setup Swarm: Ambiente [$ENV_LABEL] | Managers: $NUM_MANAGERS | Workers: $NUM_WORKERS"

# 1. Criar instâncias
for i in $(seq 1 $NUM_MANAGERS); do
    multipass launch --name "swarm-mgr-$ENV_LABEL-$i" --cpus $VM_CPU --memory $VM_MEM --disk $VM_DISK
done

for i in $(seq 1 $NUM_WORKERS); do
    multipass launch --name "swarm-wrk-$ENV_LABEL-$i" --cpus $VM_CPU --memory $VM_MEM --disk $VM_DISK
done

# 2. Instalar Docker
ALL_VMS=$(multipass list | grep "$ENV_LABEL" | awk '{print $1}')
echo "📦 Instalando Docker em todos os nós..."
for vm in $ALL_VMS; do
    multipass exec $vm -- bash -c "curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker ubuntu" &
done
wait

# 3. Inicializar o Cluster no primeiro Manager
FIRST_MGR="swarm-mgr-$ENV_LABEL-1"

# Captura de IP Robusta (independente do nome da interface)
MGR_IP=$(multipass exec $FIRST_MGR -- hostname -I | awk '{print $1}')

if [ -z "$MGR_IP" ]; then
    echo "❌ Erro: Não foi possível capturar o IP do Manager."
    exit 1
fi

echo "🛠️ Inicializando Swarm no $FIRST_MGR ($MGR_IP)..."

multipass exec $FIRST_MGR -- docker swarm leave --force 2>/dev/null
multipass exec $FIRST_MGR -- docker swarm init --advertise-addr $MGR_IP

# Captura Tokens
WORKER_TOKEN=$(multipass exec $FIRST_MGR -- docker swarm join-token worker -q)
MANAGER_TOKEN=$(multipass exec $FIRST_MGR -- docker swarm join-token manager -q)

# 4. Juntar outros Managers
if [ $NUM_MANAGERS -gt 1 ]; then
    for i in $(seq 2 $NUM_MANAGERS); do
        MGR_NAME="swarm-mgr-$ENV_LABEL-$i"
        echo "🔗 Juntando Manager extra: $MGR_NAME..."
        multipass exec $MGR_NAME -- docker swarm join --token $MANAGER_TOKEN $MGR_IP:2377
    done
fi

# 5. Juntar Workers e aplicar Labels
for i in $(seq 1 $NUM_WORKERS); do
    WRK_NAME="swarm-wrk-$ENV_LABEL-$i"
    echo "🔗 Juntando Worker: $WRK_NAME..."
    multipass exec $WRK_NAME -- docker swarm join --token $WORKER_TOKEN $MGR_IP:2377

    echo "🏷️ Aplicando label env=$ENV_LABEL em $WRK_NAME..."
    multipass exec $FIRST_MGR -- docker node update --label-add env=$ENV_LABEL $WRK_NAME
done

echo -e "\n✅ Cluster [$ENV_LABEL] configurado!"
multipass exec $FIRST_MGR -- docker node ls
