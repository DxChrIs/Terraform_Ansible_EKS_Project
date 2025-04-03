#############################################
#              AWS PROVIDER                #
#############################################
# Se define el proveedor de AWS y la región en la que se desplegará el cluster.
provider "aws" {
    region = var.region
}

#############################################
#           ZONAS DE DISPONIBILIDAD         #
#############################################
# Se filtran las zonas locales, ya que actualmente no son compatibles con grupos de nodos gestionados.
data "aws_availability_zones" "available" {
    filter {
        name   = "opt-in-status"
        values = ["opt-in-not-required"]
    }
}

#############################################
#            NOMBRE DEL CLÚSTER            #
#############################################
# Se almacena el nombre del clúster en una variable local.
locals {
    cluster_name = var.instance_name
}

#############################################
#                 VPC                      #
#############################################
# Se crea una VPC con sus subredes públicas y privadas.
module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "5.8.1"
    name    = "example_vpc"

    # Definición del rango de direcciones IP de la VPC.
    cidr = "10.0.0.0/16"
    azs  = slice(data.aws_availability_zones.available.names, 0, 3)

    # Subredes privadas y públicas dentro de la VPC.
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

    # Se habilita un NAT Gateway para permitir el tráfico saliente desde subredes privadas.
    enable_nat_gateway = true
    single_nat_gateway = true
    enable_dns_hostnames = true

    # Etiquetas para las subredes públicas y privadas.
    public_subnet_tags = {
        "kubernetes.io/role/elb" = 1  # Subredes públicas para balanceo de carga externo.
    }

    private_subnet_tags = {
        "kubernetes.io/role/internal-elb" = 1  # Subredes privadas para balanceo de carga interno.
    }
}

#############################################
#             INSTANCIAS EC2                #
#############################################
# Instancia de Windows Server 2019
# resource "aws_instance" "windows_instance" {
#     ami           = var.windows_ami_id # Reemplazar con la AMI de Windows Server 2019
#     instance_type = "t2.micro"
#     subnet_id     = module.vpc.private_subnets[0] # Usar la primera subred pública
#     associate_public_ip_address = true
#     security_groups = [ aws_security_group.windows_rdp.id ]

#     # Usar una configuración de RDP
#     user_data = <<-EOF
#         <powershell>
#         Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

#         Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

#         Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

#         Restart-Service TermService -Force
#         </powershell>
#     EOF

#     tags = {
#         Name = "WindowsInstance"
#     }
# }

# # Instancia de Linux Ubuntu
# resource "aws_instance" "linux_instance" {
#     ami           = var.linux_ami_id # Reemplazar con la AMI de Ubuntu
#     instance_type = "t2.micro"
#     subnet_id = module.vpc.private_subnets[1] # Usar la segunda subred pública
#     associate_public_ip_address = true
#     security_groups = [ aws_security_group.linux_ssh.id ]

#     # Usar una configuración de SSH
#     user_data = <<-EOF
#         #!/bin/bash
#         sudo apt-get update -y
#         sudo apt-get install -y openssh-server
#         sudo systemctl enable ssh
#         sudo systemctl start ssh
#     EOF
#     tags = {
#         Name = "LinuxInstance"
#     }
# }

#############################################
#              Auto Scaling                 #
#############################################
# Grupo de Autoscaling para Windows Server 2019
# resource "aws_autoscaling_group" "windows_asg" {
#     desired_capacity     = 2
#     max_size             = 2
#     min_size             = 1
#     vpc_zone_identifier  = module.vpc.private_subnets
#     launch_configuration = aws_launch_configuration.windows_launch_config.id
# }

# Grupo de Autoscaling para Linux Ubuntu
# resource "aws_autoscaling_group" "linux_asg" {
#     desired_capacity     = 2
#     max_size             = 2
#     min_size             = 1
#     vpc_zone_identifier  = module.vpc.private_subnets
#     launch_configuration = aws_launch_configuration.linux_launch_config.id
# }

#############################################
#              ELASTIC IPs                  #
#############################################
# resource "aws_eip" "windows_eip" {}

# resource "aws_eip_association" "windows_eip_association" {
#     instance_id = aws_instance.windows_instance.id
#     allocation_id = aws_eip.windows_eip.id
# }

# resource "aws_eip" "linux_eip" {}

# resource "aws_eip_association" "linux_eip_association" {
#     instance_id = aws_instance.linux_instance.id
#     allocation_id = aws_eip.linux_eip.id
# }

#############################################
#            SECURITY GROUP                 #
#############################################
resource "aws_security_group" "linux_ssh" {
    name        = "allow_linux_ssh"
    description = "Allow SSH traffic"
    vpc_id      = module.vpc.vpc_id

    # Regla para SSH en Linux
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Regla para permitir todo el tráfico saliente
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_security_group" "windows_rdp" {
    name        = "allow_windows_rdp"
    description = "Allow RDP traffic"
    vpc_id      = module.vpc.vpc_id

    # Regla para RDP en Windows Server
    ingress {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Regla para permitir todo el tráfico saliente
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#############################################
#                  EKS                      #
#############################################
# Se despliega un clúster EKS en la VPC creada.
module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "20.8.5"

    cluster_name    = local.cluster_name
    cluster_version = "1.29"

    # Configuración de acceso público al endpoint del clúster.
    cluster_endpoint_public_access           = true
    enable_cluster_creator_admin_permissions = true

    # Se agregan complementos del clúster, como el controlador CSI de EBS.
    cluster_addons = {
        aws-ebs-csi-driver = {
            service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
        }
        coredns = {
            most_recent = true
        }
        kube-proxy = {
            most_recent = true
        }
        vpc-cni = {
            most_recent = true
        }
    }

    # Se asocia el clúster a la VPC y a sus subredes privadas.
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets

    # Definición del grupo de nodos gestionados por EKS. 
    # Se habilita el auto scaling y se especifica el tipo de instancia.
    eks_managed_node_groups = {
        # Se define el grupo de nodos 1 para Linux.
        linux_nodes = {
            name          = "linux_node_group"
            subnet_ids    = module.vpc.private_subnets  # Subredes publicas para los nodos NO CAMBIAR A PUBLICO O EXPLOTA

            min_size      = 1
            max_size      = 2
            desired_size  = 1

            ami_type = "AL2_x84_64"
            instance_types = ["t2.micro"]  # Tipo de instancia para los nodos
            
            node_role_arn = aws_iam_role.eks_node_role.arn  # Rol de IAM para los nodos
            security_groups = [aws_security_group.linux_ssh.id]  # Grupo de seguridad para los nodos
            ec2_ssh_key = var.my-key-pair # Nombre de la clave SSH para acceder a los nodos
            labels = {
                "node-type" = "linux"
            }
        }

        # Se define el grupo de nodos 2 para Windows.
        windows_nodes = {
            name          = "windows_node_group"
            subnet_ids    = module.vpc.private_subnets  # Subredes publicas para los nodos NO CAMBIAR A PUBLICO O EXPLOTA

            min_size      = 1
            max_size      = 2
            desired_size  = 1

            ami_type       = "WINDOWS_CORE_2019_x86_64"
            instance_types = ["t2.micro"]
            
            node_role_arn = aws_iam_role.eks_node_role.arn  # Rol de IAM para los nodos
            security_groups = [aws_security_group.windows_rdp.id]  # Grupo de seguridad para los nodos
            labels = {
                "node-type" = "windows"
            }
        }
    }
}

#############################################
#               POLÍTICA IAM                #
#############################################
# Se obtiene la política IAM predefinida para el controlador EBS CSI.
data "aws_iam_policy" "ebs_csi_policy" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Se crea el rol de IAM para los nodos EKS, permitiendo el acceso a la VPC y a los recursos de AWS.
resource "aws_iam_role" "eks_node_role" {
    name               = "${local.cluster_name}-node-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = "sts:AssumeRole"
            Sid:""
            Principal = {
            Service = "ec2.amazonaws.com"
            }
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
    role       = aws_iam_role.eks_node_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly_policy" {
    role       = aws_iam_role.eks_node_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
    role       = aws_iam_role.eks_node_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

#############################################
#        ROL IAM PARA INTEGRACIÓN OIDC      #
#############################################
# Se crea un rol IAM para permitir la integración con el proveedor OIDC de EKS.
module "irsa-ebs-csi" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "4.0.0"

    create_role                   = true
    role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
    provider_url                  = module.eks.oidc_provider
    role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}