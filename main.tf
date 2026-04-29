provider "aws" {
  region = "us-east-1"
}

# חיפוש ה-AMI הכי מעודכן של Amazon Linux 2023
data "aws_ami" "latest_amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# --- תשתיות רשת ---

resource "aws_vpc" "weather_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "weather-vpc" }
}

resource "aws_subnet" "weather_subnet" {
  vpc_id                  = aws_vpc.weather_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = { Name = "weather-subnet" }
}

resource "aws_internet_gateway" "weather_igw" {
  vpc_id = aws_vpc.weather_vpc.id
  tags   = { Name = "weather-igw" }
}

resource "aws_route_table" "weather_rt" {
  vpc_id = aws_vpc.weather_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.weather_igw.id
  }
}

resource "aws_route_table_association" "weather_rta" {
  subnet_id      = aws_subnet.weather_subnet.id
  route_table_id = aws_route_table.weather_rt.id
}

# --- אבטחה ---

resource "aws_security_group" "weather_sg" {
  name   = "weather-sg"
  vpc_id = aws_vpc.weather_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s API for Lens"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Weather App Frontend"
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# מפתח SSH
resource "aws_key_pair" "weather_key" {
  key_name   = "weather-server-key"
  public_key = file("~/.ssh/weather_aws_key.pub")
}

# --- המכונה (EC2) ---

resource "aws_instance" "weather_server" {
  ami                    = data.aws_ami.latest_amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.weather_subnet.id
  vpc_security_group_ids = [aws_security_group.weather_sg.id]
  key_name               = aws_key_pair.weather_key.key_name

  root_block_device {
    volume_size = 20 
  }

  tags = { Name = "weather-gitops-server" }

  user_data = <<-EOF
              #!/bin/bash
              # 1. הגדרת Swap של 2GB למניעת קריסות זיכרון
              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # 2. התקנת K3s בגרסה קלה
              curl -sfL https://get.k3s.io | sh -s - --disable traefik --disable metrics-server

              # 3. הכנת ה-Kubeconfig ל-User
              mkdir -p /home/ec2-user/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
              chown ec2-user:ec2-user /home/ec2-user/.kube/config

              # 4. התקנת ArgoCD Core
              kubectl create namespace argocd
              kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml
              EOF
}

# --- בסיס נתונים (DynamoDB) ---

resource "aws_dynamodb_table" "weather_history" {
  name           = "weather_history"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "search_id"

  attribute {
    name = "search_id"
    type = "S" # String (UUID/Timestamp)
  }

  tags = {
    Name        = "weather-tracker-db"
    Environment = "dev"
  }
}

# --- פלטים ---

output "server_public_ip" {
  value = aws_instance.weather_server.public_ip
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.weather_history.name
}