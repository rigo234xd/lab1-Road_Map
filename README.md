# 🚗 RoadMap - Infraestructura Cloud AWS

**Autores:** Benjamín Olea & Rigoberto Alvarado

Este repositorio contiene el script de automatización y los archivos necesarios para desplegar la infraestructura web del proyecto **RoadMap** utilizando los servicios de Amazon Web Services (AWS) mediante la línea de comandos (AWS CLI).

---

## 📋 1. Requisitos Previos

Antes de ejecutar el script, asegúrate de tener tu entorno preparado:

1. **Par de claves (.pem):** Debes tener tu archivo de llaves (ej. `mi-llave.pem`) en la misma carpeta que el archivo `deploy.sh`.
2. **Seguridad del Repositorio:** Asegúrate de crear un archivo `.gitignore` y agregar el nombre de tu llave `.pem` dentro de él para evitar subirla a GitHub por accidente.
3. **Configuración del Script:** Abre el archivo `deploy.sh` en tu editor de código, ve a la **línea 94** y asegúrate de colocar el nombre exacto de tu par de claves (sin la extensión `.pem`).
4. **Permisos de la Llave:** Abre tu terminal (Git Bash) y dale los permisos de lectura correctos a tu llave privada ejecutando:
   `chmod 400 ruta/a/tu/archivo/mi-llave.pem`

---

## 🚀 2. Ejecución del Despliegue

Una vez configurado lo anterior, abre Git Bash en la carpeta raíz de tu proyecto y ejecuta el script de automatización:

`./deploy.sh`

_(Nota: Si usas una versión antigua del script y el proceso se pausa mostrando un mensaje de `---más---` en la parte inferior, simplemente presiona la tecla `q` para continuar)._

---

## 📤 3. Subir los Archivos del Sitio Web

Cuando el script finalice, te entregará la **IP Pública** de tu servidor. Ahora debemos enviar los archivos locales de tu página hacia la nube de AWS usando el comando seguro `scp`:

`scp -i ruta/a/tu/archivo/mi-llave.pem -r ./sitio-web/* ec2-user@COLOCAR_LA_IP:/home/ec2-user/`

---

## ⚙️ 4. Configuración Interna del Servidor

Ahora necesitamos entrar al servidor para mover los archivos que acabamos de subir hacia el disco adicional de datos (volumen EBS).

**1. Conéctate por SSH:**
`ssh -i ruta/a/tu/archivo/mi-llave.pem ec2-user@COLOCAR_LA_IP`

> ⚠️ **Atención:** Si es la primera vez que te conectas, la terminal te preguntará: _"Are you sure you want to continue connecting (yes/no/[fingerprint])?"_. Escribe **`yes`** y presiona Enter.

**2. Verifica los archivos:**
Una vez dentro del servidor, escribe `ls` y presiona Enter. Deberías ver los archivos de tu página web listados en la pantalla.

**3. Mueve los archivos al disco web (Apache):**
Ejecuta los siguientes comandos en orden para mover tu sitio web al disco de datos, ajustar los permisos y reiniciar el servidor web:

`sudo rm -rf /mnt/datos/*`
`sudo mv /home/ec2-user/* /mnt/datos/ 2>/dev/null`
`sudo chown -R apache:apache /mnt/datos`
`sudo chmod -R 755 /mnt/datos`
`sudo systemctl restart httpd`

---

## 🌐 5. Acceso al Sitio

¡Tu plataforma ya está en línea! Puedes visualizar el proyecto ingresando la IP pública en cualquier navegador web.

📍 **IP Pública de Producción:** http://3.238.140.110
