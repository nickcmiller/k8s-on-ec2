#INSTALL kubectl BINARY WITH CURL ON LINUX

# Create configuration file for containerd:
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
# Apply new settings:
sudo sysctl --system
# Install containerd:
sudo apt-get update && sudo apt-get install -y containerd
# Create default configuration file for containerd:
sudo mkdir -p /etc/containerd
# Generate default containerd configuration and save to the newly created default file:
sudo containerd config default | sudo tee /etc/containerd/config.toml
# Restart containerd to ensure new configuration file usage:
sudo systemctl restart containerd



# Disable swap:
sudo swapoff -a
# Install dependency packages:
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
# Download and add GPG key:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
# Add Kubernetes to repository list:
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
# Update package listings:
sudo apt-get update
# Install Kubernetes packages (Note: If you get a dpkg lock message, just wait a minute or two before trying the command again):
sudo apt-get install -y kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00
# Turn off automatic updates:
sudo apt-mark hold kubelet kubeadm kubectl



# Initialize the Kubernetes cluster on the control plane node using kubeadm (Note: This is only performed on the Control Plane Node):
echo 1 > /proc/sys/net/ipv4/ip_forward
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.24.0
# Set kubectl access:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


# kubectl get nodes

# On the control plane node, install Calico Networking:
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# In the control plane node, create the token and copy the kubeadm join command (NOTE:The join command can also be found in the output from kubeadm init command):
kubeadm token create --print-join-command

# Verify that containerd is running:
# sudo systemctl status containerd

# Check status of the control plane node or test access to cluster:
# kubectl get nodes


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