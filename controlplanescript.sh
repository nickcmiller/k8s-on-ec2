

#Set up hostnames
sudo hostnamectl set-hostname k8s-control
sudo hostnamectl set-hostname k8s-worker1
sudo hostnamectl set-hostname k8s-worker2

#Set up hostfile
cat << EOF >> /etc/hosts
172.31.2.212 k8s-control
172.31.8.96 k8s-worker1
172.31.4.238 k8s-worker2
EOF

# Create configuration fi
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

#Immediately enble modules without having to restart server
modprobe overlay
modprobe br_netfilter

#Networking level configurations
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply new settings:
sysctl --system


# Install containerd:
apt-get update && sudo apt-get install -y containerd

# Create default configuration file for containerd:
mkdir -p /etc/containerd

# Generate default containerd configuration and save to the newly created default file:
containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd to ensure new configuration file usage:
systemctl restart containerd

#Verify that containerd is running:
systemctl status containerd

# Disable swap:
swapoff -a

# Install dependency packages:
apt-get update && sudo apt-get install -y apt-transport-https curl
# Download and add GPG key:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
# Add Kubernetes to repository list:
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
# Update package listings:
apt-get update
# Install Kubernetes packages (Note: If you get a dpkg lock message, just wait a minute or two before trying the command again):
apt-get install -y kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00
# Turn off automatic updates:
apt-mark hold kubelet kubeadm kubectl



#Possible debug step
#echo 1 > /proc/sys/net/ipv4/ip_forward

-------------

# Initialize the Kubernetes cluster on the control plane node using kubeadm (Note: This is only performed on the Control Plane Node):
kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.24.0

# Set kubectl access through kube config:
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config


#Test step
# kubectl get nodes

# On the control plane node, install Calico Networking:
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

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