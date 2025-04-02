# Salida comentada: ID de la instancia EC2
# output "instance_id" {
#     description = "ID of the EC2 instance"  # ID único de la instancia EC2 creada.
#     value = aws_instance.app_server.id  # Devuelve el ID de la instancia EC2.
# }

# Salida comentada: Dirección IP pública de la instancia EC2
# output "instance_public_ip" {
#     description = "Public IP address of the EC2 instance"  # Dirección IP pública asociada a la instancia EC2.
#     value = aws_instance.app_server.public_ip  # Devuelve la IP pública de la instancia EC2.
# }

# Salida del endpoint del clúster EKS
output "cluster_endpoint" {
    description = "Endpoint for EKS control panel"  # URL del endpoint para acceder al panel de control de EKS.
    value = module.eks.cluster_endpoint  # Devuelve el endpoint del clúster EKS.
}

# Salida del ID del grupo de seguridad del clúster
output "cluster_security_group_id" {
    description = "Security group ids attached to the cluster control panel"  # ID(s) del grupo de seguridad asociado al panel de control del clúster EKS.
    value = module.eks.cluster_security_group_id  # Devuelve el ID del grupo de seguridad asociado al clúster EKS.
}

# Salida de la región de AWS
output "region" {
    description = "AWS region"  # Región de AWS donde se ha desplegado la infraestructura.
    value       = var.region  # Devuelve la región especificada en la variable `region`.
}

# Salida del nombre del clúster EKS
output "cluster_name" {
    description = "EKS Name"  # Nombre del clúster EKS creado.
    value = module.eks.cluster_name  # Devuelve el nombre del clúster EKS.
}

output "windows_public_ip" {
    value = aws_instance.windows_instance.public_ip  # Devuelve la IP pública de la instancia EC2 Windows.
}