terraform {
    # Sección para definir los proveedores requeridos
    required_providers {
        aws = {
            source = "hashicorp/aws"  # Especifica el proveedor de AWS de HashiCorp.
            version = "~> 5.47.0"     # Especifica la versión mínima del proveedor de AWS a utilizar.
        }
        random = {
            source = "hashicorp/random"  # Especifica el proveedor de recursos aleatorios de HashiCorp.
            version = "~> 3.6.1"         # Especifica la versión mínima del proveedor de recursos aleatorios a utilizar.
        }
        tls = {
            source = "hashicorp/tls"     # Especifica el proveedor de TLS de HashiCorp.
            version = "~> 4.0.5"         # Especifica la versión mínima del proveedor TLS a utilizar.
        }
        cloudinit = {
            source = "hashicorp/cloudinit"  # Especifica el proveedor de CloudInit de HashiCorp.
            version = "~> 2.3.4"            # Especifica la versión mínima del proveedor de CloudInit a utilizar.
        }
        kubernetes = {
            source = "hashicorp/kubernetes"  # Especifica el proveedor de Kubernetes de HashiCorp.
            version = ">= 2.16.1"            # Especifica la versión mínima del proveedor de Kubernetes a utilizar.
        }
    }

    # Versión mínima de Terraform requerida para ejecutar este archivo
    required_version = "~> 1.3"  # Especifica la versión mínima de Terraform a utilizar.
}
