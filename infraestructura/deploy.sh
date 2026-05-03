#!/bin/bash

echo "Iniciando despliegue de infraestructura para RoadMap..."

# ==========================================
# 1. Variables de Entorno y Configuración
# ==========================================
# Usamos variables exportadas para facilitar la reproducibilidad del script
export REGION="us-east-1"
export AZ_PUB="${REGION}a"
export AZ_PRIV="${REGION}b"

# Justificación del CIDR: 10.0.0.0/16 ofrece 65,536 IPs, ideal para estructurar 
# múltiples subredes en el futuro sin riesgo de agotar direcciones.
export CIDR_VPC="10.0.0.0/16"
export CIDR_PUB="10.0.1.0/24"
export CIDR_PRIV="10.0.2.0/24"

# Obtener IP dinámica para acceso SSH, asegurando que solo nuestra máquina pueda conectarse a la instancia EC2
echo "Obteniendo la IP pública local..."
export MI_IP=$(curl -s https://checkip.amazonaws.com)/32
echo "IP detectada para acceso SSH: $MI_IP"

# Configuración de Instancia (usamos t3.micro para mantenernos en el free tier)
export INSTANCE_TYPE="t3.micro"
export KEY_NAME="lab1-llave" 
# Obtenemos dinámicamente la última imagen de Amazon Linux 2023
export AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 --query 'Parameters[0].Value' --output text --region $REGION)


# ==========================================
# 2. Infraestructura de Red (VPC y Subredes)
# ==========================================
echo "Creando VPC..."
export VPC_ID=$(aws ec2 create-vpc --cidr-block $CIDR_VPC --query Vpc.VpcId --output text --region $REGION)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=VPC-RoadMap --region $REGION

echo "Creando Subred Pública..."
export SUBNET_PUB_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $CIDR_PUB --availability-zone $AZ_PUB --query Subnet.SubnetId --output text --region $REGION)
aws ec2 create-tags --resources $SUBNET_PUB_ID --tags Key=Name,Value=Subred-Publica-RoadMap --region $REGION

echo "Creando Subred Privada..."
export SUBNET_PRIV_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $CIDR_PRIV --availability-zone $AZ_PRIV --query Subnet.SubnetId --output text --region $REGION)
aws ec2 create-tags --resources $SUBNET_PRIV_ID --tags Key=Name,Value=Subred-Privada-RoadMap --region $REGION


# ==========================================
# 3. Internet Gateway y Ruteo
# ==========================================
echo "Creando y adjuntando internet gateway..."
export IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text --region $REGION)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION

echo "Configurando tablas de ruteo para la subred pública..."
export ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text --region $REGION)
# Permitimos que la tabla de ruteo envíe tráfico hacia Internet a través del IGW
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION > /dev/null
# Asociamos la tabla de ruteo exclusivamente a la subred pública
aws ec2 associate-route-table --subnet-id $SUBNET_PUB_ID --route-table-id $ROUTE_TABLE_ID --region $REGION > /dev/null


# ==========================================
# 4. Seguridad (Security Groups)
# ==========================================
echo "Creando security group..."
export SG_ID=$(aws ec2 create-security-group --group-name "WebSG-RoadMap" --description "Permitir HTTP global y SSH restringido" --vpc-id $VPC_ID --query GroupId --output text --region $REGION)

# Regla 1: Permitir tráfico HTTP (puerto 80) desde cualquier origen para servir el sitio
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION > /dev/null

# Regla 2: Permitir tráfico SSH (puerto 22) restringido SOLO a nuestra IP local
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MI_IP --region $REGION > /dev/null


# ==========================================
# 5. Cómputo (EC2)
# ==========================================
echo "Lanzando Instancia EC2 en subred pública..."
export INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_PUB_ID \
    --associate-public-ip-address \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=Servidor-Web-RoadMap --region $REGION

echo "Esperando a que la instancia EC2 ($INSTANCE_ID) esté en ejecución..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION


# ==========================================
# 6. Almacenamiento (EBS)
# ==========================================
echo "Creando Volumen EBS Adicional (8GB, gp3)..."
# El volumen debe crearse en la misma Zona de Disponibilidad que la instancia
export VOL_ID=$(aws ec2 create-volume --availability-zone $AZ_PUB --size 8 --volume-type gp3 --query VolumeId --output text --region $REGION)
aws ec2 create-tags --resources $VOL_ID --tags Key=Name,Value=Volumen-Datos-RoadMap --region $REGION

echo "Esperando a que el volumen EBS ($VOL_ID) esté disponible..."
aws ec2 wait volume-available --volume-ids $VOL_ID --region $REGION

echo "Adjuntando Volumen EBS a la Instancia..."
aws ec2 attach-volume --volume-id $VOL_ID --instance-id $INSTANCE_ID --device /dev/sdf --region $REGION > /dev/null

echo "=========================================="
echo "¡INFRAESTRUCTURA DESPLEGADA CON ÉXITO!"
echo "=========================================="
export IP_PUBLICA=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region $REGION)
echo "Puedes conectarte a tu instancia mediante SSH con:"
echo "ssh -i \"$KEY_NAME.pem\" ec2-user@$IP_PUBLICA"