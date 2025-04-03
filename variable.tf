# Definición de la variable "instance_name"
variable "instance_name" {
    description = "Value of the Name tag for the EC2 instance"  # Descripción que explica el propósito de la variable: el valor de la etiqueta 'Name' de la instancia EC2.
    type = string  # El tipo de la variable es un string (cadena de texto).
    default = "ChrisAndJaimeClusterProject1"  # Valor por defecto de la variable: "ExampleEKSCluster", que se utilizará si no se especifica otro valor.
}

# Definición de la variable "region"
variable "region" {
    description = "AWS region"  # Descripción que explica el propósito de la variable: la región de AWS donde se desplegará la infraestructura.
    type = string  # El tipo de la variable es un string (cadena de texto).
    default = "us-east-1"  # Valor por defecto de la variable: "us-east-2", que se utilizará si no se especifica otro valor.
}

# variable "linux_ami_id" {
#     description = "AMI ID for the Linux instance"  # Descripción que explica el propósito de la variable: el ID de la AMI para la instancia Linux.
#     type        = string  # El tipo de la variable es un string (cadena de texto).
#     default     = "ami-084568db4383264d4"  # Valor por defecto de la variable: ID de la AMI para Amazon Linux 2 en la región us-east-2.
# }

# variable "windows_ami_id" {
#     description = "AMI ID for the Windows instance"  # Descripción que explica el propósito de la variable: el ID de la AMI para la instancia Windows.
#     type        = string  # El tipo de la variable es un string (cadena de texto).
#     default     = "ami-05f08ad7b78afd8cd"  # Valor por defecto de la variable: ID de la AMI para Windows Server en la región us-east-2.
# }

variable "my-key-pair" {
    description = "Key pair name"  # Descripción que explica el propósito de la variable: el nombre del par de claves para acceder a la instancia EC2.
    type        = string  # El tipo de la variable es un string (cadena de texto).
    default     = "tester"  # Valor por defecto de la variable: "my-key-pair", que se utilizará si no se especifica otro valor.
}