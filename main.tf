locals {
  key_pair_name = "LabKey"
  instance_type = "t2.medium"
  ami_id        = "ami-0574da719dca65348"
  cluster_name  = "K8s-Cluster"

}

resource "aws_security_group" "k8s_security_group" {
  name        = "MyKubernetesClusterSG"
  description = "Security Group for Kubernetes Cluster"

  ingress {
    description      = "SSH access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP access"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "External Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow k8s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    description = "ETCD"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Health Check"
    from_port   = 10248
    to_port     = 10248
    protocol    = "tcp"
    self        = true
  }
  
   ingress {
    description = "kubelet health check"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kube Scheduler"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kube Control Manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    self        = true
  }
  
  ingress {
    description = "Read only kubelet API"
    from_port   = 10255
    to_port     = 10255
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  tags = {
    Name = "MyKubernetesClusterSG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "control_plane_node" {
  instance_type = local.instance_type
  ami           = local.ami_id
  tags = {
    Name = "${local.cluster_name}-control_plane"
  }
  key_name        = local.key_pair_name
  security_groups = ["${aws_security_group.k8s_security_group.name}"]
  # user_data       = file("${path.module}/controlplanescript.sh")
  depends_on      = [aws_security_group.k8s_security_group]
}

resource "aws_instance" "worker_node" {
  count         = 2
  instance_type = local.instance_type
  ami           = local.ami_id
  tags = {
    Name = "${local.cluster_name}-worker-node-${count.index}"
  }
  key_name        = local.key_pair_name
  security_groups = ["${aws_security_group.k8s_security_group.name}"]
  depends_on      = [aws_security_group.k8s_security_group]
}

output "control_plane_connection_script" {
  value = "ssh -i '${local.key_pair_name}.pem' ubuntu@${aws_instance.control_plane_node.public_dns}"
}

output "work_node_dns" {
  value = aws_instance.worker_node.*.public_dns
}


output "control_plane_ip" {
  value = aws_instance.control_plane_node.private_ip
}

output "work_node_ip" {
  value = aws_instance.worker_node.*.private_ip
}
