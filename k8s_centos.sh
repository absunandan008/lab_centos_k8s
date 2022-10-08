#!/bin/bash

##K8s centos

#### Forwarding IPv4 and letting iptables see bridged traffic 
##https://docs.oracle.com/en/operating-systems/olcne/1.1/start/netfilter.html

lsmod | grep br_netfilter
sudo modprobe br_netfilter


cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

## Install Container d
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine


sudo yum install -y yum-utils
sudo yum-config-manager \
   --add-repo \
   https://download.docker.com/linux/centos/docker-ce.repo

#sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo yum install containerd.io -y

## add support for contaiber d to use systemd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
## change SystemdCgroup = true
sudo vi /etc/containerd/config.toml 
sudo systemctl restart containerd

## List firewall
firewall-cmd --list-all
## open firewall 
sudo firewall-cmd --zone=public --permanent --add-port 6443/tcp
sudo firewall-cmd --zone=public --add-port=10250/tcp --permanent
sudo firewall-cmd --reload

sudo swapoff -a

##install kubeadm
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

# on control
## https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

## now we need to get admin config to run kubect;
#Your Kubernetes control-plane has initialized successfully!

#To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

#You should now deploy a Pod network to the cluster.
#Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#  /docs/concepts/cluster-administration/addons/

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.0/manifests/custom-resources.yaml
##watch till everything start
watch kubectl get pods -n calico-system

#You can now join any number of machines by running the following on each node
#as root:
    ##kubeadm join 172.16.43.135:6443 --token kalqfl.kj377q2jmvkxtd5l --discovery-token-ca-cert-hash sha256:6ba9bdfb48a9c16c405deefe1824ff10b076bc8df4cf3ad5716e4e63c351c3de
  kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

  ## createjoin command
  sudo kubeadm token create --print-join-command
