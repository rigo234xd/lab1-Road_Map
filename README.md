Benjamin Olea
Rigoberto Alvarado

RoadMap

Instrucciones para ejecutar el script de infraestructura
Abriremos nuestro deploy e iremos a la linea 94, aqui debe ir el nombre de nuestro par de claves.

Comenzando con tener nuestro deploy.sh y la el par de claves (.pem) en la misma carpeta, creando un .gitnore con anticipación para que este ultimo no se suba a github, tambien podemos inicializar la ruta con el comando "chmod 400 ruta/a/tu/archivo/mi-llave.pem", una vez que tenemos esto listo, abriremos nuestro terminal de git bash, una vez escribimos y ejecutamos el comando de "./deploy.sh" estando en la carpeta del archivo (en caso de que no se ejecute completo y salga ---más--- abajo, apretamos la letra q).

subimos nuestros archivos del sitio web al servicio de aws
"scp -i ruta/a/tu/archivo/mi-llave.pem -r ./sitio-web/\* ec2-user@colocar-la-ip:/home/ec2-user/"
Una vez que termine la ejecución de nuestro scripts debemos conectarnos por ssh
"ssh -i ruta/a/tu/archivo/mi-llave.pem ec2-user@colocarlaip"
Si sale un mensaje "Are you sure you want to continue connecting (yes/no/[fingerprint])?" escribimos que "yes" y damos enter
para comprobar que vamos bien hasta aqui, escribimos "ls" y deberiamos ver los archivos de la pagina web

sudo rm -rf /mnt/datos/_
sudo mv /home/ec2-user/_ /mnt/datos/ 2>/dev/null
sudo chown -R apache:apache /mnt/datos
sudo chmod -R 755 /mnt/datos
sudo systemctl restart httpd

IP PUBLICA: http://3.238.140.110
