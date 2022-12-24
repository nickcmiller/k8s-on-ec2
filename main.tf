locals{
  image_name = "test-nginx"
  key_pair_name = "LabKey"
  instance_type = "t2.medium"
  ami_id = "ami-0574da719dca65348"
  instance_tags = {
      Name = "K8s-Ubuntu-Instance"
  }
  
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"

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

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
  
  lifecycle{
    create_before_destroy = true
  }
}

resource "aws_instance" "ec2_instance" {
    instance_type = local.instance_type
    ami = local.ami_id
    tags = local.instance_tags
    key_name = local.key_pair_name
    user_data = "${path.module}/userdata.sh"
    security_groups = ["${aws_security_group.allow_ssh_http.name}"]
    depends_on = [aws_security_group.allow_ssh_http]
}

output "ec2_connection_script"{
    value = "ssh -i '${local.key_pair_name}.pem' ubuntu@${aws_instance.ec2_instance.public_dns}"
    
}