# aptdb
Bash script to dump, restore and backup local or remote (SSH+rsync) MySQL compatible databases

```
aptdb es un programa de ayuda a la migración de bases de datos. Accede a bases
de datos a través de mysql-client y opcionalmente mediante una conexión ssh.

Opciones:
     --help                   Muestra la ayuda y termina el programa.

     --s-ssh USUARIO@HOST     Acceso ssh a servidor de acceso a base de datos
                              de origen.
 -u, --s-user USUARIO         Usuario MySQL de la base de datos de origen.
 -p, --s-pass PASSWORD        Contraseña MySQL de la base de datos de origen.
 -h, --s-host HOSTNAME        Nombre de servidor al que conectar a la base de
                              datos de origen. P. ej. bbdd.rds.amazonaws.com
 -d, --s-database DB_NAME     Nombre de la base de datos de origen a la que
                              conectar

     --d-ssh USUARIO@HOST     Acceso ssh a servidor de acceso a base de datos
                              de destino.
 -U, --d-user USUARIO         Usuario MySQL de la base de datos de destino.
 -P, --d-pass PASSWORD        Contraseña MySQL de la base de datos de destino.
 -H, --d-host HOSTNAME        Nombre de servidor al que conectar a la base de
                              datos de destino. P. ej. bbdd.aptitude.ws
 -D, --d-database DB_NAME     Nombre de la base de datos de destino a la que
                              conectar

 -i, --include FILE           Solo descarga o sube las tablas que se encuentren
                              en el fichero de includes FILE.
 -e, --exclude FILE           Descarga o sube todas las tablas de la base de
                              datos exceptuando las del fichero de exludes FILE

 -r, --download               Descarga la base de datos de origen al directorio
                              de trabajo.
 -w, --upload                 Escribe los ficheros .sql del directorio de
                              trabajo a la base de datos de destino.
                              Si existiera la opcion -r|--download solo se
                              subirian los ficheros sql que se hubieran
                              descargado, si no, todos los existentes en el
                              directorio de trabajo.
 -s, --split                  Descompone los ficheros *.sql en ficheros más
                              pequeños de 25 lineas cada uno. Util para copias
                              de seguridad incrementales.
 -j, --join                   Une los ficheros descompuestos en ficheros *.sql
                              completos.
     --delete-sql             Elimina los ficheros *.sql al terminar la
                              ejecución.
     --delete-split           Elimina los ficheros descompuestos al terminar la
                              ejecución.
 -l, --load-conf FILE         Carga un fichero de configuracion.
                              dump de la base de datos al completo y luego bajar
                              todo, se va haciendo tabla a tabla. Puede ser util
                              cuando el espacio en disco es limitado.
     --cwd DIR                Cambia el directorio de trabajo.
 -v, --verbose                Muestra información extra durante la ejecución.
     --scp                    Utiliza scp en vez de rsync para descargar los ficheros remotos.


EXTRA
=====================================
Puedes agilizar mucho la ejecución de este fichero reutilizando las conexiones
ssh. Para ello, copia las siguientes lineas a tu fichero ~/.ssh/config

Host *
ControlMaster auto
ControlPath ~/.ssh/sockets/%r@%h-%p
ControlPersist 1

Y crear el directorio donde se almacenaran las conexiones:
mkdir -p ~/.ssh/sockets
Mas info en: https://puppet.com/blog/speed-up-ssh-by-reusing-connections
```