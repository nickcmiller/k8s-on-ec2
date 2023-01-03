#Useful breakdown: 
#https://serverfault.com/questions/1118051/failed-to-run-kubelet-validate-service-connection-cri-v1-runtime-api-is-not-im
#https://thenewstack.io/how-to-deploy-kubernetes-with-kubeadm-and-containerd/

#Set up hostnames
# sudo hostnamectl set-hostname k8s-control
# sudo hostnamectl set-hostname k8s-worker1
# sudo hostnamectl set-hostname k8s-worker2

# Master
# firewall-cmd --permanent --add-port=6443/tcp # Kubernetes API server
# firewall-cmd --permanent --add-port=2379-2380/tcp # etcd server client API
# firewall-cmd --permanent --add-port=10250/tcp # Kubelet API
# firewall-cmd --permanent --add-port=10251/tcp # kube-scheduler
# firewall-cmd --permanent --add-port=10252/tcp # kube-controller-manager
# firewall-cmd --permanent --add-port=8285/udp # Flannel
# firewall-cmd --permanent --add-port=8472/udp # Flannel
# firewall-cmd --add-masquerade --permanent
# # only if you want NodePorts exposed on control plane IP as well
# firewall-cmd --permanent --add-port=30000-32767/tcp
# firewall-cmd --reload
# systemctl restart firewalld


# # Node
# firewall-cmd --permanent --add-port=10250/tcp
# firewall-cmd --permanent --add-port=8285/udp # Flannel
# firewall-cmd --permanent --add-port=8472/udp # Flannel
# firewall-cmd --permanent --add-port=30000-32767/tcp
# firewall-cmd --add-masquerade --permanent
# firewall-cmd --reload
# systemctl restart firewalld


#Set up hostfiles
cat << EOF >> /etc/hosts
172.31.82.164 k8s-control
172.31.87.133 k8s-worker1
172.31.95.175 k8s-worker2
EOF

# Kubeadm | kubectl | kubelet install
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt update -y
apt -y install vim git curl wget kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00
apt-mark hold kubelet kubeadm kubectl

#Start and enable the kubelet service
systemctl enable --now kubelet

#Load the br_netfilter module and let iptables see bridged traffic
modprobe overlay
modprobe br_netfilter
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply new settings
sysctl --system

# Create configuration files for Containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

#Immediately enble modules without having to restart server
modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply new settings
sysctl --system

#Install and configure containerd 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
apt update -y
apt install -y containerd.io
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

#Start containerd
systemctl restart containerd
systemctl enable containerd

#download images required to setup Kubernetes
kubeadm config images pull --image-repository=registry.k8s.io --cri-socket unix:///run/containerd/containerd.sock --kubernetes-version v1.26.0

#Possible debug step
echo 1 > /proc/sys/net/ipv4/ip_forward

# Disable swap
swapoff -a

-------------

# Initialize the Kubernetes cluster on the control plane node using kubeadm
kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.26.0 --cri-socket unix:///run/containerd/containerd.sock

#Allow kubectl to interact with the cluster
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

#Install CNI Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.20.2/Documentation/kube-flannel.yml
#kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

#Test step
# kubectl get nodes

-------------------------

#Troubleshooting
systemctl stop kubelet
systemctl start kubelet
strace -eopenat kubectl version


# In the control plane node, create the token and copy the kubeadm join command (NOTE:The join command can also be found in the output from kubeadm init command):
# kubeadm token create --print-join-command

# Verify that containerd is running:
# sudo systemctl status containerd

# Check status of the control plane node or test access to cluster:
# kubectl get nodes


-------------------------


#Create Nginx

cat << EOF >> /home/ubuntu/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

kubectl apply -f /home/ubuntu/nginx-deployment.yaml

#Update the yaml file to scale the deployment to 4 nginx containers
#To scale a deployment to 4 containers, you will need to update the replicas field in the deployment configuration file.


#Verify the change via the command line
kubectl get pods -l app=nginx


cat << EOF >> /home/ubuntu/multi-container-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
  - name: debian
    image: debian:latest
    command: ["/bin/bash"]
    args: ["-c", "while true; do echo Hello from the Debian container; sleep 10; done"]
EOF

kubectl apply -f /home/ubuntu/multi-container-pod.yaml
