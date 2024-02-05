#! /bin/bash

KUBE_VERSION="1.29"

# 방화벽 해제
echo $(tput setaf 4)"[INFO] Disable Firewall...$(tput setaf 7)"
sudo ufw disable

# swap off
echo $(tput setaf 4)"[INFO] Swap Memory off...$(tput setaf 7)"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo $(tput setaf 4)"[INFO] Syncronizing NTP Server...$(tput setaf 7)"
sudo apt -y install ntp
sudo systemctl restart ntp
sudo systemctl status ntp
sudo ntpq -p

echo $(tput setaf 4)"[INFO] /proc/sys/net/ipv4/ip_forward -> 1...$(tput setaf 7)"
echo '1' | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

echo $(tput setaf 4)"[INFO] containerd setting...$(tput setaf 7)$(tput setaf 7)"
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf > /dev/null
overlay
br_netfilter
EOF

echo $(tput setaf 4)"[INFO] registering kernel...$(tput setaf 7)$(tput setaf 7)"
sudo modprobe overlay
sudo modprobe br_netfilter


echo $(tput setaf 4)"[INFO] Adding Bridge-Related Settings to the iptables for Node-to-Node Communication$(tput setaf 7)"

echo $(tput setaf 5)"[1] 99-kubernetes-cri.conf...$(tput setaf 7)"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

echo $(tput setaf 5)"[2] modules-load > k8s.conf...$(tput setaf 7)"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf > /dev/null
br_netfilter
EOF

echo $(tput setaf 5)"[2] sysctl.d > k8s.conf...$(tput setaf 7)"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf > /dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

echo $(tput setaf 4)"[INFO] Applying System Setting$(tput setaf 7)"
sudo sysctl --system


echo $(tput setaf 4)"[INFO] Installing the required packages...$(tput setaf 7)"
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

echo $(tput setaf 4)"[INFO] Installing Docker...$(tput setaf 7)"

echo $(tput setaf 5)"[1] Add Docker's official GPG key...$(tput setaf 7)"
# Add Docker's official GPG key:
sudo apt-get update
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo $(tput setaf 5)"[2] Add the repository to Apt sources...$(tput setaf 7)"
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

echo $(tput setaf 5)"[3] Installing Docker latest...$(tput setaf 7)"
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

echo $(tput setaf 4)"[INFO] Setting Containerd...$(tput setaf 7)"
sudo sh -c "containerd config default > /etc/containerd/config.toml"
echo $(tput setaf 5)"[1] SystemdCgroup = false -> true...$(tput setaf 7)"
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml

echo $(tput setaf 4)"[INFO] Setting docker daemon...$(tput setaf 7)"
echo $(tput setaf 5)"[1] Creating directory located /etc/docker...$(tput setaf 7)"
sudo mkdir -p /etc/docker
echo $(tput setaf 5)"[2] Adding daemon.json to /etc/docker...$(tput setaf 7)"
cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF

echo $(tput setaf 4)"[INFO] System service restart ...$(tput setaf 7)"
echo $(tput setaf 5)"[1] Creating directory located /etc/systemd/system/docker.service.d...$(tput setaf 7)"
sudo mkdir -p /etc/systemd/system/docker.service.d
echo $(tput setaf 5)"[2] Modifier docker user"
sudo usermod -aG docker $USER
echo $(tput setaf 5)"[3] daemon-reload"
sudo systemctl daemon-reload
echo $(tput setaf 5)"[4] enable docker"
sudo systemctl enable docker
echo $(tput setaf 5)"[5] restart docker"
sudo systemctl restart docker
echo $(tput setaf 5)"[6] containerd.service"
sudo systemctl restart containerd.service


echo $(tput setaf 4)"[INFO] Kubernetes Install ...$(tput setaf 7)"
echo $(tput setaf 5)"[1] Add Keyring for kubernetes$(tput setaf 7)"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


echo $(tput setaf 5)"[2] Installing Kubernetes Tools$(tput setaf 7)"
sudo apt-get update
sudo apt -y install kubelet kubeadm kubectl
echo $(tput setaf 4)"[INFO] Congratulation Enjoy Kubernetes!!...$(tput setaf 7)"
