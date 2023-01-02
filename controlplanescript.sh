#Set up hostnames
# sudo hostnamectl set-hostname k8s-control
# sudo hostnamectl set-hostname k8s-worker1
# sudo hostnamectl set-hostname k8s-worker2

#Set up hostfiles
# cat << EOF >> /etc/hosts
# 172.31.3.204 k8s-control
# 172.31.59.55 k8s-worker1
# 172.31.53.64 k8s-worker2
# EOF

# Kubeadm | kubectl | kubelet install
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt update -y
apt -y install vim git curl wget kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00
apt-mark hold kubelet kubeadm kubectl

#Load the br_netfilter module and let iptables see bridged traffic
modprobe overlay
modprobe br_netfilter
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
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

# Apply new settings:
sysctl --system

#Install and configure containerd 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt update -y
sudo apt install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

#Start containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

sudo kubeadm config images pull --image-repository=registry.k8s.io --cri-socket unix:///run/containerd/containerd.sock --kubernetes-version v1.26.0

#Possible debug step
#echo 1 > /proc/sys/net/ipv4/ip_forward

-------------

# Initialize the Kubernetes cluster on the control plane node using kubeadm (Note: This is only performed on the Control Plane Node):
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.26.0 --cri-socket unix:///run/containerd/containerd.sock

# Set kubectl access through kube config:
sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

# Disable swap:
swapoff -a

#Install CNI Flannel
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

#Test step
# kubectl get nodes

-------------------------

#Troubleshooting
# systemctl stop kubelet
# systemctl start kubelet
# strace -eopenat kubectl version


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
