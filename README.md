# Docker Swarm

## Setup de máquinas

### Criando as máquinas virtuais com Multipass
> Esse passos estão compilados em [setup-swarm.sh](./setup-swarm.sh)

```bash
# Cria o Manager
multipass launch --name swarm-manager --cpus 1 --memory 1G --disk 5G

# Cria os Workers
multipass launch --name swarm-worker1 --cpus 1 --memory 1G --disk 5G
multipass launch --name swarm-worker2 --cpus 1 --memory 1G --disk 5G
```

### Instalando o Docker nas máquinas virtuais

```bash
for vm in swarm-manager swarm-worker1 swarm-worker2; do
  multipass exec $vm -- bash -c "curl -fsSL https://get.docker.com | sh"
  multipass exec $vm -- sudo usermod -aG docker ubuntu
done
```

## Configurando o Docker Swarm

### Inicializando cluster

#### Lista de ips

```bash
multipass list
```

#### Inicializando o Manager

```bash
MANAGER_IP=$(multipass info swarm-manager | grep IPv4 | awk '{print $2}')
multipass exec swarm-manager -- docker swarm init --advertise-addr $MANAGER_IP
```

#### Adicionando Workers ao cluster

```bash
JOIN_TOKEN=$(multipass exec swarm-manager -- docker swarm join-token -q worker)
for worker in swarm-worker1 swarm-worker2; do
  WORKER_IP=$(multipass info $worker | grep IPv4 | awk '{print $2}')
  multipass exec $worker -- docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377
done
```

### Verificando o cluster
```bash
multipass exec swarm-manager -- docker node ls
```

## Destruindo as máquinas virtuais

```bash
multipass delete --all && multipass purge
```

## Setup Portainer

### Deploy do Portainer no Swarm

```bash
multipass exec swarm-manager -- bash -c "curl -L https://downloads.portainer.io/ce-lts/portainer-agent-stack.yml -o portainer-agent-stack.yml && docker stack deploy -c portainer-agent-stack.yml portainer"
```
