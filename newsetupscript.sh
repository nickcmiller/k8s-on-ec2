#become root
sudo su

#set hostname
hostnamectl set-hostname k8s-control

#Maps hostnames to IP addresses
cat << EOF >> /etc/hosts
172.31.11.145 k8s-control
172.31.88.11 k8s-worker1
172.31.94.68 k8s-worker2
EOF

#exit root
exit

#exit server and sign back in
exit

#update server and install apt-transport-https and curl
sudo apt-get -y update
sudo apt install -y  apt-transport-https curl

#Install containerd 
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get -y update
sudo apt-get -y install containerd.io

#Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

#set SystemdCgroup = true within config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

#Restart containerd daemon
sudo systemctl restart containerd

#Enable containerd to start automatically at boot time
sudo systemctl enable containerd

#install kubeadm, kubectl, kubelet,and kubernetes-cni 
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt install -y kubeadm kubelet kubectl kubernetes-cni

#disable swap
sudo swapoff -a

#load the br_netfilter module in the Linux kernel
sudo modprobe br_netfilter

#check if a swap entry exists and remove it if it does
#sudo vim /etc/fstab

#enable ip-forwarding 
sudo su 
echo 1 > /proc/sys/net/ipv4/ip_forward
exit


---------

#initialize kubernetes cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

#Allow kubectl to interact with the cluster
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#export KUBECONFIG as root
sudo su
export KUBECONFIG=/etc/kubernetes/admin.conf
exit

#Install CNI Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.20.2/Documentation/kube-flannel.yml
