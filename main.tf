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
resource "aws_launch_configuration" "windows_launch_config" {
    name          = "windows_launch_config"
    image_id           = var.windows_ami_id # Reemplazar con la AMI de Windows Server 2019
    instance_type = "t2.micro"
    security_groups = [ aws_security_group.windows_rdp.id ]

    # Usar una configuración de RDP
    user_data = <<-EOF
        <powershell>
        Enable-NetFirewallRule -DisplayName 'Remote Desktop - User Mode (TCP-In)'
        </powershell>
    EOF
}

# Instancia de Linux Ubuntu
resource "aws_launch_configuration" "linux_launch_config" {
    name          = "linux_launch_config"
    image_id           = var.linux_ami_id # Reemplazar con la AMI de Ubuntu
    instance_type = "t2.micro"
    security_groups = [ aws_security_group.linux_ssh.id ]

    # Usar una configuración de SSH
    user_data = <<-EOF
        #!/bin/bash
        sudo apt-get update -y
        sudo apt-get install -y openssh-server
        sudo systemctl enable ssh
        sudo systemctl start ssh
    EOF
}

#############################################
#              Auto Scaling                 #
#############################################
# Grupo de Autoscaling para Windows Server 2019
resource "aws_autoscaling_group" "windows_asg" {
    desired_capacity     = 2
    max_size             = 2
    min_size             = 1
    vpc_zone_identifier  = module.vpc.private_subnets
    launch_configuration = aws_launch_configuration.windows_launch_config.id
}

# Grupo de Autoscaling para Linux Ubuntu
resource "aws_autoscaling_group" "linux_asg" {
    desired_capacity     = 2
    max_size             = 2
    min_size             = 1
    vpc_zone_identifier  = module.vpc.private_subnets
    launch_configuration = aws_launch_configuration.linux_launch_config.id
}

#############################################
#              ELASTIC IPs                  #
#############################################
resource "aws_eip" "windows_eip" {
    instance = aws_autoscaling_group.windows_asg.id
}

resource "aws_eip" "linux_eip" {
    instance = aws_autoscaling_group.linux_asg.id
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
            instance_type = "t2.micro"
            min_size      = 1
            max_size      = 2
            desired_size  = 2
            node_role_arn = module.eks.cluster_iam_role_arn
            subnet_ids    = module.vpc.private_subnets  # Subredes privadas para los nodos

            asg_name = aws_autoscaling_group.linux_asg.name  # Nombre del grupo de autoscaling para Linux

            labels = {
                "node-type" = "linux"
            }
        }

        # Se define el grupo de nodos 2 para Windows.
        windows_nodes = {
            name          = "windows_node_group"
            instance_type = "t2.micro"
            min_size      = 1
            max_size      = 2
            desired_size  = 2
            node_role_arn = module.eks.cluster_iam_role_arn
            subnet_ids    = module.vpc.private_subnets  # Subredes privadas para los nodos

            asg_name = aws_autoscaling_group.windows_asg.name  # Nombre del grupo de autoscaling para Windows

            labels = {
                "node-type" = "windows"
            }
        }
    }
}

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
#        POLÍTICA IAM PARA EBS CSI         #
#############################################
# Se obtiene la política IAM predefinida para el controlador EBS CSI.
data "aws_iam_policy" "ebs_csi_policy" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
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