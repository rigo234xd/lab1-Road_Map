#!/bin/bash

# Región configurada: us-east-1 (Norte de Virginia)

# 1. CONFIGURACIÓN DE REGIÓN Y ZONA DE DISPONIBILIDAD
REGION="us-east-1"
AZ1="us-east-1a"
AZ2="us-east-1b"
aws configure set default.region $REGION

echo "Iniciando despliegue de infraestructura para RoadMap en la región: $REGION..."

# 2. CREAR LA VPC
echo "Creando VPC..."
export VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=RoadMap
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

echo "VPC creada: $VPC_ID"

# 3. CREAR SUBRED PÚBLICA
echo "Creando subred pública..."
export SUBNET_PUB=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 --availability-zone $AZ1 \
  --query 'Subnet.SubnetId' --output text)

aws ec2 create-tags --resources $SUBNET_PUB --tags Key=Name,Value=RoadMap-subred-publica
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB --map-public-ip-on-launch

echo "Subred Pública creada: $SUBNET_PUB"

# 3.5 CREAR SUBRED PRIVADA
echo "Creando subred privada..."
export SUBNET_PRV=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 --availability-zone $AZ2 \
  --query 'Subnet.SubnetId' --output text)

aws ec2 create-tags --resources $SUBNET_PRV --tags Key=Name,Value=RoadMap-subred-privada

echo "Subred Privada creada: $SUBNET_PRV"

# 4. INTERNET GATEWAY
echo "Creando Internet Gateway..."
export IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=RoadMap-igw
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

echo "Internet Gateway conectado: $IGW_ID"

# 5. TABLA DE RUTEO
echo "Creando tabla de ruteo..."
export RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=RoadMap-rt

# Crear ruta hacia el Internet Gateway (0.0.0.0/0)
aws ec2 create-route --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Asociar tabla de ruteo a la subred pública
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_PUB

echo "Tabla de Ruteo configurada: $RT_ID"

# 6. SECURITY GROUP
echo "Creando Security Group..."
export SG_ID=$(aws ec2 create-security-group --group-name RoadMap-sg \
  --description 'Security Group para aplicacion RoadMap' --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=RoadMap-sg

# Permitir tráfico HTTP desde cualquier lugar
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# Permitir tráfico SSH solo desde la IP pública del usuario
IP_PUBLICA=$(curl -s -4 ifconfig.me)

aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${IP_PUBLICA}/32

echo "Security Group configurado: $SG_ID"

# 7. LANZAR INSTANCIA EC2
echo "Lanzando instancia EC2..."
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0453ec754f44f9a4a \
  --instance-type t2.micro \
  --key-name vockey \
  --subnet-id $SUBNET_PUB \
  --security-group-ids $SG_ID \
  --associate-public-ip-address \
  --user-data '#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Espera dinámica al disco extra
while [ ! -b /dev/xvdf ]; do
  sleep 5
done

# Formateo y montaje del EBS
mkfs -t ext4 /dev/xvdf
mkdir -p /mnt/datos
mount /dev/xvdf /mnt/datos

# Configuración del sitio RoadMap en el volumen extra
echo "<h1>Bienvenido al sistema RoadMap</h1>" > /mnt/datos/index.html
rm -rf /var/www/html
ln -s /mnt/datos /var/www/html' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=RoadMap-webserver

echo "Lanzando instancia EC2: $INSTANCE_ID con servidor web incluido..."

# 8. CREAR Y ADJUNTAR VOLUMEN EBS ADICIONAL
echo "Creando volumen EBS de 8GB en $AZ1..."
export VOL_ID=$(aws ec2 create-volume --size 8 --volume-type gp3 \
  --availability-zone $AZ1 --query 'VolumeId' --output text)

aws ec2 create-tags --resources $VOL_ID --tags Key=Name,Value=RoadMap-datos

echo "Esperando a que el volumen esté disponible..."
aws ec2 wait volume-available --volume-ids $VOL_ID

echo "Adjuntando volumen a la instancia RoadMap..."
aws ec2 attach-volume --volume-id $VOL_ID \
  --instance-id $INSTANCE_ID --device /dev/sdf

echo "Volumen $VOL_ID adjuntado correctamente."

# 9. VERIFICACIÓN FINAL
echo "Esperando a que la instancia se inicialice (esto puede tomar un minuto)..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "=========================================================="
echo "DESPLIEGUE EXITOSO"
echo "Dirección IP Pública: $PUBLIC_IP"
echo "URL del sitio: http://$PUBLIC_IP"
echo "Nota: El sitio web puede tardar entre 1 y 2 minutos extra en responder después de encender."
echo "=========================================================="