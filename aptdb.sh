#!/bin/bash

SOURCE_DB_SSH_SERVER=""
SOURCE_DB_HOST=""
SOURCE_DB_USER=""
SOURCE_DB_PASS=""
SOURCE_DB_SCHEMA=""

DESTINATION_DB_SSH_SERVER=""
DESTINATION_DB_HOST=""
DESTINATION_DB_USER=""
DESTINATION_DB_PASS=""
DESTINATION_DB_SCHEMA=""

DOWNLOAD=false
UPLOAD=false
SPLIT_SQL_FILES=false
JOIN_SQL_FILES=false
DELETE_SQL_FILES=false
DELETE_SPLIT_SQL_FILES=false
SHOW_HELP=false
VERBOSE=false
SCP=false


EXCLUDED_TABLES_FILE=""
INCLUDED_TABLES_FILE=""

CONFIGURATION_FILE=""

WORKING_DIRECTORY=""


askUser() { # $1 texto, $2 default

	defaultvalue=$2
	case $2 in 
		[yY][eE][sS]|[yY]|[sS]|[sS][iI]|[sS][íÍ])
			read -r -p "$1 (S/n): " response
		;;
		*)
			defaultvalue="n"
			read -r -p "$1 (s/N): " response
		;;
	esac

	if [[ -z $response ]]; then
		response=${defaultvalue}
	fi
	case $response in
		[yY][eE][sS]|[yY]|[sS]|[sS][iI]|[sS][íÍ]) 
			# 0 = true;
			return 0
		;;
		[nN][oO]|[nN])
			# 1 = false;
			return 1
		;;
		*)
			if askUser "$1" "${defaultvalue}"; then
				# 0 = true
				return 0
			else
				# 1 = false
				return 1 
			fi
		;;
	esac

}

PRINT_OVER_SAME_LINE_LAST_STRING_LENGHT=0
printOverSameLine() { # $1 texto
	for i in $(seq 0 ${PRINT_OVER_SAME_LINE_LAST_STRING_LENGHT});
	do
		echo -n " "
	done
	echo -n ""$'\r'

	echo -n "${1}"$'\r'
	PRINT_OVER_SAME_LINE_LAST_STRING_LENGHT=${#1}
}

get_abs_filename() {
	echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

verbose() { # $1 texto, $2 level (de momento level no funciona)
	if [ ${VERBOSE} = true ]; then
		echo "$1"
	fi
}

showHelp() {

	echo "aptdb es un programa de ayuda a la migración de bases de datos. Accede a bases"
	echo "de datos a través de mysql-client y opcionalmente mediante una conexión ssh."
	echo ""
	echo "Opciones:"
	echo "     --help                   Muestra la ayuda y termina el programa. "
	echo ""
	echo "     --s-ssh USUARIO@HOST     Acceso ssh a servidor de acceso a base de datos"
	echo "                              de origen. "
	echo " -u, --s-user USUARIO         Usuario MySQL de la base de datos de origen. "
	echo " -p, --s-pass PASSWORD        Contraseña MySQL de la base de datos de origen."
	echo " -h, --s-host HOSTNAME        Nombre de servidor al que conectar a la base de"
	echo "                              datos de origen. P. ej. bbdd.rds.amazonaws.com"
	echo " -d, --s-database DB_NAME     Nombre de la base de datos de origen a la que"
	echo "                              conectar"
	echo ""
	echo "     --d-ssh USUARIO@HOST     Acceso ssh a servidor de acceso a base de datos"
	echo "                              de destino. "
	echo " -U, --d-user USUARIO         Usuario MySQL de la base de datos de destino. "
	echo " -P, --d-pass PASSWORD        Contraseña MySQL de la base de datos de destino."
	echo " -H, --d-host HOSTNAME        Nombre de servidor al que conectar a la base de"
	echo "                              datos de destino. P. ej. bbdd.aptitude.ws"
	echo " -D, --d-database DB_NAME     Nombre de la base de datos de destino a la que"
	echo "                              conectar"
	echo ""
	echo " -i, --include FILE           Solo descarga o sube las tablas que se encuentren"
	echo "                              en el fichero de includes FILE. "
	echo " -e, --exclude FILE           Descarga o sube todas las tablas de la base de"
	echo "                              datos exceptuando las del fichero de exludes FILE"
	echo ""
	echo " -r, --download               Descarga la base de datos de origen al directorio"
	echo "                              de trabajo. "
	echo " -w, --upload                 Escribe los ficheros .sql del directorio de"
	echo "                              trabajo a la base de datos de destino. "
	echo "                              Si existiera la opcion -r|--download solo se"
	echo "                              subirian los ficheros sql que se hubieran"
	echo "                              descargado, si no, todos los existentes en el"
	echo "                              directorio de trabajo. "
	echo " -s, --split                  Descompone los ficheros *.sql en ficheros más"
	echo "                              pequeños de 25 lineas cada uno. Util para copias"
	echo "                              de seguridad incrementales. "
	echo " -j, --join                   Une los ficheros descompuestos en ficheros *.sql"
	echo "                              completos. "
	echo "     --delete-sql             Elimina los ficheros *.sql al terminar la"
	echo "                              ejecución. "
	echo "     --delete-split           Elimina los ficheros descompuestos al terminar la"
	echo "                              ejecución. "
#	echo "     --working-directoy DIR   Establece un directorio de trabajo distinto al de la ejecución del programa. "
	echo " -l, --load-conf FILE         Carga un fichero de configuracion. "
	echo "                              dump de la base de datos al completo y luego bajar"
	echo "                              todo, se va haciendo tabla a tabla. Puede ser util"
	echo "                              cuando el espacio en disco es limitado. "
	echo "     --cwd DIR                Cambia el directorio de trabajo. "
	echo " -v, --verbose                Muestra información extra durante la ejecución. "
	echo "     --scp                    Utiliza scp en vez de rsync para descargar los ficheros remotos. "
	echo ""
	echo ""
	echo "EXTRA"
	echo "====================================="
	echo "Puedes agilizar mucho la ejecución de este fichero reutilizando las conexiones"
	echo "ssh. Para ello, copia las siguientes lineas a tu fichero ~/.ssh/config"
	echo ""
	echo "Host *"
	echo "ControlMaster auto"
	echo "ControlPath ~/.ssh/sockets/%r@%h-%p"
	echo "ControlPersist 1" #Segundos que se persiste la conexion. Para este script basta con 1 segundo ya que las conexiones se realizan de modo secuencial sin esperas. 
	echo ""
	echo "Y crear el directorio donde se almacenaran las conexiones: "
	echo "mkdir -p ~/.ssh/sockets"
	echo "Mas info en: https://puppet.com/blog/speed-up-ssh-by-reusing-connections"
	exit 0;

}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
	--help)
	SHOW_HELP=true
	;;
	--s-ssh)
	SOURCE_DB_SSH_SERVER="$2"
	shift # past argument
	;;
	-u|--s-user)
	SOURCE_DB_USER="$2"
	shift
	;;
	-p|--s-pass)
	SOURCE_DB_PASS="$2"
	shift
	;;
	-h|--s-host)
	SOURCE_DB_HOST="$2"
	shift
	;;
	-d|--s-database)
	SOURCE_DB_SCHEMA="$2"
	shift
	;;
	--d-ssh)
	DESTINATION_DB_SSH_SERVER="$2"
	shift # past argument
	;;
	-U|--d-user)
	DESTINATION_DB_USER="$2"
	shift
	;;
	-P|--d-pass)
	DESTINATION_DB_PASS="$2"
	shift
	;;
	-H|--d-host)
	DESTINATION_DB_HOST="$2"
	shift
	;;
	-D|--d-database)
	DESTINATION_DB_SCHEMA="$2"
	shift
	;;

	-i|--include)
	INCLUDED_TABLES_FILE=$(get_abs_filename "$2")
	shift
	if [[ ! -f "${INCLUDED_TABLES_FILE}" ]]; then
		echo "El fichero de includes ${INCLUDED_TABLES_FILE} no existe. "
		exit 1
	fi
	;;
	-e|--exclude)
	EXCLUDED_TABLES_FILE=$(get_abs_filename "$2")
	shift
	if [[ ! -f "${EXCLUDED_TABLES_FILE}" ]]; then
		echo "El fichero de excludes ${EXCLUDED_TABLES_FILE} no existe. "
		exit 1
	fi
	;;

	-r|--download)
	DOWNLOAD=true
	;;
	-w|--upload)
	UPLOAD=true
	;;
	-s|--split)
	SPLIT_SQL_FILES=true
	;;
	-j|--join)
	JOIN_SQL_FILES=true
	;;
	--delete-sql)
	DELETE_SQL_FILES=true
	;;
	--delete-split)
	DELETE_SPLIT_SQL_FILES=true
	;;
	-v|--verbose)
	VERBOSE=true
	;;
	--scp)
	SCP=true
	;;
	-l|--load-conf)
	CONFIGURATION_FILE="$2"
	shift
	if [[ ! -f "${CONFIGURATION_FILE}" ]]; then
		echo "El fichero de configuracion ${CONFIGURATION_FILE} no existe. "
		exit 1
	fi
	;;
	--cwd)
	WORKING_DIRECTORY="$2"
	shift
	;;
	*)
	echo "Opcion $1 no soportada. "
	SHOW_HELP=true
	;;
esac
shift # past argument or value
done


# Mostramos ayuda
if [ ${SHOW_HELP} = true ] ; then 
	showHelp
fi

# Cargamos fichero de configuracion externo
if [[ ! -z "${CONFIGURATION_FILE}" ]] ; then 
	verbose "Cargando configuracion desde ${CONFIGURATION_FILE}"
	source "${CONFIGURATION_FILE}"
	verbose "Configuracion cargada"
fi

# Comprobamos existencia de fichero de tablas en directorio de trabajo.
if [ -f "tables.tmp" ]; then
	if askUser "Existen ficheros tables.tmp. Esto suele indicar que ya existe una ejecucion de este script sobre este directorio de trabajo, o que la anterior ejecucion acabó inesperadamente. ¿Desea continuar?" "s"; then echo "seguimos"; else exit 1; fi
fi

# Comprobamos parametros obligatorios de download
if [ ${DOWNLOAD} = true ]; then
	if [[ -z ${SOURCE_DB_USER} ]]; then
		echo "Para descargar es necesario el nombre de usuario de la base de datos de origen (-u | --s-user). "
		exit 1
	fi
	if [[ -z ${SOURCE_DB_SCHEMA} ]]; then
		echo "Para descargar es necesario el nombre de la base de datos de origen (-d | --s-database). "
		exit 1
	fi
fi

# Comprobamos parametros obligatorios de upload
if [ ${UPLOAD} = true ]; then
	if [[ -z ${DESTINATION_DB_USER} ]]; then
		echo "Para subir es necesario el nombre de usuario de la base de datos de destino (-U | --d-user). "
		exit 1
	fi
	if [[ -z ${DESTINATION_DB_SCHEMA} ]]; then
		echo "Para subir es necesario el nombre de la base de datos de destino (-D | --d-database). "
		exit 1
	fi
fi

# Comprobamos parametros incompatibles
if [ ${DOWNLOAD} = true ]; then
	if [ ${JOIN_SQL_FILES} = true ]; then
		# No podemos tener 2 origenes de base de datos
		echo "La opción download (-r, --download) es incompatible con la opción join (-j, --join)"
		exit 1
	fi
fi

#Comprobamos conexion con base de datos de origen
if [ ${DOWNLOAD} = true ]; then

	verbose "Comprobando conexión con base de datos de origen. "

	PARAMS_O="-u ${SOURCE_DB_USER}"
	if [[ ! -z ${SOURCE_DB_PASS} ]]; then
		PARAMS_O="${PARAMS_O} -p${SOURCE_DB_PASS}"
	fi
	if [[ ! -z ${SOURCE_DB_HOST} ]]; then
		PARAMS_O="${PARAMS_O} -h ${SOURCE_DB_HOST}"
	fi
	PARAMS_O="${PARAMS_O} ${SOURCE_DB_SCHEMA}"

	#Comprobamos conexion
	#http://serverfault.com/questions/173978/from-a-shell-script-how-can-i-check-whether-a-mysql-database-exists
	if [[ -z "${SOURCE_DB_SSH_SERVER}" ]] ; then 
		if ! echo "use ${SOURCE_DB_SCHEMA};" | mysql ${PARAMS_O}; then
			echo "Error al conectar a la base de datos origen con los mediante: mysql ${PARAMS_O}"
			exit 1
		fi
	else
		if ! echo "use ${SOURCE_DB_SCHEMA};" | ssh ${SOURCE_DB_SSH_SERVER} "mysql ${PARAMS_O}"; then
			echo "Error al conectar a la base de datos origen con los mediante: ssh ${SOURCE_DB_SSH_SERVER} "'"'"mysql ${PARAMS_O}"'"'
			exit 1
		fi
	fi

	verbose "Conexión con base de datos de origen comprobada. "

fi

#Comprobamos conexion con base de datos de destino
if [ ${UPLOAD} = true ]; then

	verbose "Comprobando conexión con base de datos de destino. "

	PARAMS_D="-u ${DESTINATION_DB_USER}"
	if [[ ! -z ${DESTINATION_DB_PASS} ]]; then
		PARAMS_D="${PARAMS_D} -p${DESTINATION_DB_PASS}"
	fi
	if [[ ! -z ${DESTINATION_DB_HOST} ]]; then
		PARAMS_D="${PARAMS_D} -h ${DESTINATION_DB_HOST}"
	fi
	PARAMS_D="${PARAMS_D} ${DESTINATION_DB_SCHEMA}"

	#Comprobamos conexion
	#http://serverfault.com/questions/173978/from-a-shell-script-how-can-i-check-whether-a-mysql-database-exists
	if [[ -z "${DESTINATION_DB_SSH_SERVER}" ]] ; then 
		if ! echo "use ${DESTINATION_DB_SCHEMA};" | mysql ${PARAMS_D}; then
			echo "Error al conectar a la base de datos destino con los mediante: mysql ${PARAMS_D}"
			exit 1
		fi
	else
		if ! echo "use ${DESTINATION_DB_SCHEMA};" | ssh ${DESTINATION_DB_SSH_SERVER} "mysql ${PARAMS_D}"; then
			echo "Error al conectar a la base de datos destino con los mediante: ssh ${DESTINATION_DB_SSH_SERVER} "'"'"mysql ${PARAMS_D}"'"'
			exit 1
		fi
	fi

	verbose "Conexión con base de datos de destino comprobada. "

fi

# Nos movemos al directorio de trabajo y lo creamos si es necesario. 
if [[ ! -z "${WORKING_DIRECTORY}" ]] ; then 
	verbose "Creando directorio de trabajo en el caso de que no existiera. "
	mkdir -p "${WORKING_DIRECTORY}"
	verbose "Moviendo ejecución a entorno de trabajo ${WORKING_DIRECTORY}"
	cd "${WORKING_DIRECTORY}"
	verbose "Directorio cambiado a nuevo entorno de trabajo. "
fi

#Creamos un fichero tables.tmp que contiene las tablas con las que se va a trabajar. Si se bajan, seran las de la base de datos de origen, si se juntan cachitos, los sql resultantes, y si no, los que existan en el directorio de trabajo. 
if [ ${DOWNLOAD} = true ]; then
	
	verbose "Creando fichero tables.tmp en base a contenido de base de datos. "
	count=$(ls -1 *.sql 2>/dev/null | wc -l)
	if [ $count != 0 ]; then 
		echo "¡¡¡¡¡¡ ATENCIÓN !!!!!!"
		echo "Existen ficheros sql en la ruta de trabajo. Puede borrar y que el script comience de cero. Si se ha cancelado una descarga a medias y no borra los ficheros, continuará por donde se quedó. "
		if askUser "¿Desea borrarlos todos los ficheros *.sql de la ruta?" "s"; then 
			rm *.sql; 
		else 
			echo "Seguimos" 
		fi
	fi

	if [[ -z "${SOURCE_DB_SSH_SERVER}" ]] ; then 
		verbose "Creando desde cliente local. "
		echo "show tables;" | mysql ${PARAMS_O} | grep -v '^Tables_in_' > tables.tmp
	else
		verbose "Creando desde cliente remoto ${SOURCE_DB_SSH_SERVER}"
		echo "show tables;" | ssh ${SOURCE_DB_SSH_SERVER} "mysql ${PARAMS_O}" | grep -v '^Tables_in_' > tables.tmp
	fi
	verbose "Fichero tables.tmp creado. "

else # No se ha marcado la opcion de download

	if [ ${JOIN_SQL_FILES} = true ]; then

		verbose "Creando ficheros sql desde trocitos de fichero. "

		count=$(ls -1 *.sql 2>/dev/null | wc -l)
		if [ $count != 0 ]; then 
			echo "¡¡¡¡¡¡ ATENCIÓN !!!!!!"
			echo "Existen ficheros sql en la ruta de trabajo. Puede borrar y que el script comience de cero. Si no, no se podra continuar. "
			if askUser "¿Desea borrarlos todos los ficheros *.sql de la ruta?" "s"; then 
				rm *.sql; 
			else 
				echo "Opción join incompatible con la existencia de ficheros *.sql en el directorio de trabajo."
				exit 1 
			fi
		fi

		ls *.sql.* | sed "s/\.sql\.[a-z]*/.sql/g" | sort -u | xargs -I {} sh -c 'cat {}.* > {}'

		verbose "Fichreos sql creados. "

	fi

	verbose "Creando fichero tables.tmp desde ficheros sql del directorio de trabajo. "

	ls | grep "\.sql$" | sed "s/\.sql$//" > tables.tmp

	verbose "Fichero tables.tmp creado. "

fi

# Reducimos las tablas del fichero tables.tmp a las comunes entre las existentes y las del fichero includes
if [[ ! -z "${INCLUDED_TABLES_FILE}" ]]; then

	verbose "Reducimos las tablas del fichero tables.tmp a las que existan en el fichero includes. "

	# Hallamos los elementos en includes que no están en base de datos y notificamos al usuario. 
	# Set Complement | http://www.catonmat.net/blog/set-operations-in-unix-shell/ 
	count=$(comm -23 <(sort ${INCLUDED_TABLES_FILE}) <(sort tables.tmp) 2>/dev/null | wc -l)
	#             |-> Parámetros de comm: aqui puede ir 1 2 y 3. 
	#             |-> 1 representa los elementos del primer fichero pasado que no se encuentran en el segundo.
	#             |-> 2 representa los elementos del segundo fichero pasado que no se encuentran en el primero.
	#             |-> 3 representa los elementos comunes en el primer y segundo fichero. 
	#             |-> -23 indica que se muestren los del 1 (se quitan 2 y 3)

	if [ $count != 0 ]; then 
		echo "Las siguientes tablas especificadas en el fichero de include no existen en origen. " #Origen puede ser base de datos o ficheros sql de la ruta de trabajo. 
		comm -23 <(sort ${INCLUDED_TABLES_FILE}) <(sort tables.tmp)
		if askUser "¿Desea continuar?" "y"; then
			echo "continuamos"
		else
			exit 1
		fi
	fi

	# Reducimos las tablas a descargar a las comunes entre las existentes y las del fichero includes
	# Set Intersection | http://www.catonmat.net/blog/set-operations-in-unix-shell/
	comm -12 <(sort ${INCLUDED_TABLES_FILE}) <(sort tables.tmp) > tables2.tmp
	rm tables.tmp
	mv tables2.tmp tables.tmp

	verbose "Fichero tables.tmp reducido. "

fi

# Eliminamos las tablas del fichero tables.tmp que se encuentren el fichero exludes.
if [[ ! -z "${EXCLUDED_TABLES_FILE}" ]]; then

	verbose "Exluimos de tables.tmp las tablas del fichero excludes. "

	# Hallamos los elementos en excludes que no están en base de datos y notificamos al usuario. 
	# Set Complement | http://www.catonmat.net/blog/set-operations-in-unix-shell/ 
	count=$(comm -23 <(sort ${EXCLUDED_TABLES_FILE}) <(sort tables.tmp) 2>/dev/null | wc -l)

	if [ $count != 0 ]; then 
		echo "Las siguientes ${count} tablas especificadas en el fichero de exclude que no existen en la base de datos. "
		comm -23 <(sort ${EXCLUDED_TABLES_FILE}) <(sort tables.tmp)
	fi

	# Reducimos las tablas a descargar a las existentes menos las del exclude
	# Set Complement | http://www.catonmat.net/blog/set-operations-in-unix-shell/
	comm -13 <(sort ${EXCLUDED_TABLES_FILE}) <(sort tables.tmp) > tables2.tmp
	rm tables.tmp
	mv tables2.tmp tables.tmp

	verbose "Tablas excluidas. "

fi

# Descargamos las tablas tables.tmp desde origen
if [ ${DOWNLOAD} = true ]; then

	verbose "Descargando tablas a ficheros sql. "

	# Inicializamos directorio remoto
	if [[ ! -z "${SOURCE_DB_SSH_SERVER}" ]] ; then 
		REMOTE_TMP_DIR=$(ssh ${SOURCE_DB_SSH_SERVER} "mktemp -d")
	fi

	TOTAL_N=$(cat tables.tmp | wc -l | tr -d '[:space:]')
	COUNTER=0

	for X in $(cat tables.tmp)
	do
		if [ ! -f ${X}.sql ]; then

			if [[ -z "${SOURCE_DB_SSH_SERVER}" ]] ; then
				printOverSameLine "(${COUNTER}/${TOTAL_N}) dumping ${X}"
				mysqldump --single-transaction --skip-dump-date ${PARAMS_O} ${X} > ${X}.temp
				mv ${X}.temp ${X}.sql
			else
				printOverSameLine "(${COUNTER}/${TOTAL_N}) dumping ${X}"
				ssh ${SOURCE_DB_SSH_SERVER} "mysqldump --single-transaction --skip-dump-date ${PARAMS_O} ${X} > ${REMOTE_TMP_DIR}/${X}.sql"
				printOverSameLine "(${COUNTER}/${TOTAL_N}) downloading ${X}"
				if [ ${SCP} = true ]; then
					scp -p -q ${SOURCE_DB_SSH_SERVER}:${REMOTE_TMP_DIR}/${X}.sql ${X}.sql
				else
					rsync -az ${SOURCE_DB_SSH_SERVER}:${REMOTE_TMP_DIR}/${X}.sql ${X}.sql
				fi
				ssh ${SOURCE_DB_SSH_SERVER} "rm ${REMOTE_TMP_DIR}/${X}.sql"
			fi
		else
			echo skip ${X}
		fi

		COUNTER=$((COUNTER + 1))

	done

	printOverSameLine "Descargadas ${COUNTER} tablas. " #Limpiamos la linea
	echo "" 

	# Limpiamos directorio remoto
	if [[ ! -z "${SOURCE_DB_SSH_SERVER}" ]] ; then 
		ssh ${SOURCE_DB_SSH_SERVER} "rmdir ${REMOTE_TMP_DIR}"
	fi

	verbose "Tablas descargadas a ficheros sql. "

fi

# Subimos las tablas tables.tmp a destino
if [ ${UPLOAD} = true ]; then

	verbose "Subiendo tablas desde ficheros sql. "

	# Inicializamos directorio remoto
	if [[ ! -z "${DESTINATION_DB_SSH_SERVER}" ]] ; then 
		REMOTE_TMP_DIR=$(ssh ${DESTINATION_DB_SSH_SERVER} "mktemp -d")
	fi

	TOTAL_N=$(cat tables.tmp | wc -l | tr -d '[:space:]')
	COUNTER=0

	for X in $(cat tables.tmp)
	do
		if [ -f ${X}.sql ]; then
			if [[ -z "${DESTINATION_DB_SSH_SERVER}" ]] ; then
				printOverSameLine "(${COUNTER}/${TOTAL_N}) restoring ${X}"
				mysql ${PARAMS_D} < ${X}.sql
			else
				printOverSameLine "(${COUNTER}/${TOTAL_N}) uploading ${X}"
				if [ ${SCP} = true ]; then
					scp -p -q ${X}.sql ${DESTINATION_DB_SSH_SERVER}:${REMOTE_TMP_DIR}/${X}.sql
				else
					rsync -az ${X}.sql ${DESTINATION_DB_SSH_SERVER}:${REMOTE_TMP_DIR}/${X}.sql
				fi
				printOverSameLine "(${COUNTER}/${TOTAL_N}) restoring ${X}"
				ssh ${DESTINATION_DB_SSH_SERVER} "mysql ${PARAMS_D} < ${REMOTE_TMP_DIR}/${X}.sql"
				ssh ${DESTINATION_DB_SSH_SERVER} "rm ${REMOTE_TMP_DIR}/${X}.sql"
			fi
		else
			echo skip ${X}
		fi
		COUNTER=$((COUNTER + 1))
	done

	printOverSameLine "Subidas ${COUNTER} tablas. " #Limpiamos la linea
	echo "" 

	# Limpiamos directorio remoto
	if [[ ! -z "${DESTINATION_DB_SSH_SERVER}" ]] ; then 
		ssh ${DESTINATION_DB_SSH_SERVER} "rmdir ${REMOTE_TMP_DIR}"
	fi

	verbose "Tablas subidas desde ficheros sql. "

fi

# Separamos ficheros sql en trocitos de 25 lineas cada uno.
if [ ${SPLIT_SQL_FILES} = true ]; then
	verbose "Separando ficheros sql en trocitos. "
	find . -name "*.sql" | xargs -I {} split -a 4 -l 25 {} {}.
	verbose "Ficheros sql separados. "
fi

# Borramos los ficheros sql
if [ ${DELETE_SQL_FILES} = true ]; then
	verbose "Borrando ficheros sql"
	rm *.sql
	verbose "Ficheros borrados. "
fi

# Borramos los ficheros splits (trocitos) de los sqls
if [ ${DELETE_SPLIT_SQL_FILES} = true ]; then
	verbose "Borrando ficheros splits (trocitos)"
	rm *.sql.*
	verbose "Ficheros borrados"
fi

verbose "Borrando fichero tables.tmp"
rm tables.tmp
verbose "Fichero borrado"

