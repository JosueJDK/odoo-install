#!/bin/bash
################################################################################
# Script para instalar Odoo en Ubuntu
#-------------------------------------------------------------------------------
# Este script instalará Odoo en su servidor Ubuntu. Puede instalar varias instancias de Odoo
# en un Ubuntu asignando diferentes xmlrpc_ports
#-------------------------------------------------------------------------------
# Clone el fichero con el comando:
# git clone https://gist.github.com/89e486592f4c2ab7ff0be5530c92b008.git odoo
# o crea un nuevo archivo:	
# sudo nano odoo-install.sh
# Coloque el contenido de este script en él y dale permisos de ejecución:
# sudo chmod +x odoo-install.sh
# Ejecute el script para instalar Odoo:
# ./odoo-install.sh
################################################################################

##parámetros fijos
#odoo
OE_USER="odoo13"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_CUSTOM_ADDONS="/$OE_USER/custom_addons"
#El puerto predeterminado donde se ejecutará esta instancia de Odoo (siempre que use el comando -c en el terminal)
#Establezca en verdadero si desea instalarlo, falso si no lo necesita o ya lo tiene instalado.
INSTALL_WKHTMLTOPDF="True"
#Establezca el puerto Odoo predeterminado (todavía tiene que usar -c /etc/odoo-server.conf, por ejemplo, para usar esto).
OE_PORT="8013"
#Elija la versión de Odoo que desea instalar. Por ejemplo: 12.0, 11.0, 10.0, 9.0 o saas-18. Cuando se usa 'master', se instalará la versión master.
#¡IMPORTANTE! Este script contiene bibliotecas adicionales que son específicamente necesarias para Odoo 11.0
OE_VERSION="13.0"
# ¡Establezca esto en True si desea instalar Odoo Enterprise!
IS_ENTERPRISE="False"
#establecer la contraseña superadmin
echo "Introduce la contraseña para el usuario de postgress"
read OE_SUPERADMIN
OE_CONFIG="${OE_USER}-server"

##
###  WKHTMLTOPDF download links
## para tener instalada la versión correcta de wkhtmltox, para mas información consulte
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
VERSION_UBUNTU="$(cut -d':' -f2 <<<`lsb_release -c`)"
VERSION_UBUNTU="$(echo -e "${VERSION_UBUNTU}" | tr -d '[[:space:]]')"
WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.${VERSION_UBUNTU}_amd64.deb"
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.${VERSION_UBUNTU}_i386.deb

#--------------------------------------------------
# Actualiza Servidor
#--------------------------------------------------
echo -e "\n---- Actualiza Servidor ----"
sudo apt update
sudo apt upgrade -y

#--------------------------------------------------
# Instalar Servidor PostgreSQL
#--------------------------------------------------
echo -e "\n---- Instalar Servidor PostgreSQL ----"
sudo apt install postgresql libpq-dev -y

echo -e "\n---- Crear el usuario ODOO en PostgreSQL  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
sudo -u postgres psql -c "ALTER USER $OE_USER WITH PASSWORD '$OE_SUPERADMIN';"

#--------------------------------------------------
# Instalar Dependencies
#--------------------------------------------------
echo -e "\n--- Instalar Python 3 + pip3 --"
sudo apt install python3 python3-pip -y

echo -e "\n---- Instalar paquete de herramientas ----"
sudo apt install wget git bzr python-pip gdebi-core -y

echo -e "\n---- Instalar python packages ----"
sudo apt install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd 

echo -e "\n---- Instalar python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds

echo -e "\n--- Instalar otros paquetes requeridos"
sudo apt install node-clean-css node-less python-gevent python3-libsass -y

#--------------------------------------------------
# Instalar Wkhtmltopdf si es necesario
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Instale wkhtml y coloque accesos directos en el lugar correcto para ODOO 11 ----"
  #elija la opción correcta de las versiones x64 y x32:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "¡Wkhtmltopdf no está instalado debido a la elección del usuario!"
fi

echo -e "\n---- Crear usuario ODOO en el servidor ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#El usuario también debe ser agregado al grupo sudoers.
sudo adduser $OE_USER sudo

echo -e "\n---- Crear directorio de Log ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Instalar ODOO
#--------------------------------------------------
echo -e "\n==== Instalando ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Instalar Odoo Enterprise!
    echo -e "\n--- Crear enlace simbólico para nodo"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "¡Tu autenticación con Github ha fallado! Inténtalo de nuevo."
        printf "Para clonar e instalar la versión empresarial de Odoo, \ndebe ser un socio oficial de Odoo y debe tener acceso a \n http: //github.com/odoo/enterprise. \n"
        echo "SUGERENCIA: presione Ctrl + c para detener este script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Agregado código Enterprise en $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Instalar bibliotecas específicas de Enterprise ----"
    sudo pip3 install num2words ofxparse
    sudo apt install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
else
	sudo pip3 install num2words
fi

echo -e "\n---- Crear directorio de módulo personalizado ----"
sudo su $OE_USER -c "mkdir $OE_CUSTOM_ADDONS"

echo -e "\n---- Establecer permisos en la carpeta de inicio ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Crear archivo de configuración del servidor"

sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Crear archivo de configuración del servidor"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_CUSTOM_ADDONS}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Crear archivo de inicio"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Agregar ODOO como demonio/servicio (script de inicio)
#--------------------------------------------------

echo -e "* Crear archivo de inicio"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Seguridad de archivo Init"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Inicie ODOO en el arranque"
sudo update-rc.d $OE_CONFIG defaults

echo -e "* Inicio del servicio Odoo"
sudo su root -c "/etc/init.d/$OE_CONFIG start"

echo -e "* Añadiendo Odoo al firewall"
sudo ufw allow ssh
sudo ufw allow $OE_PORT
sudo ufw enable
sudo ufw reload

echo "-----------------------------------------------------------"
echo "¡Hecho! El servidor Odoo está en funcionamiento. Especificaciones:"
echo "Puerto: $OE_PORT"
echo "Usuario servidor: $OE_USER"
echo "Usuario PostgreSQL: $OE_USER"
echo "Contraseña Usuario PostgreSQL: $OE_SUPERADMIN"
echo "Ubicación del código: $OE_USER"
echo "Directorio Addons: $OE_CUSTOM_ADDONS"
echo "Iniciar servicio Odoo: sudo service $OE_CONFIG start"
echo "Detener el servicio de Odoo: sudo service $OE_CONFIG stop"
echo "Reiniciar el servicio Odoo: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"