##
# KUSANAGI WordPres Deployment for kusanagi-docker
# (C)2019 Prime-Strategy Co,Ltd
# Licenced by GNU GPL v2
#

source .kusanagi
source .kusanagi.wp
source $LIBDIR/.version

IMAGE=$([ $OPT_NGINX ] && echo $KUSANAGI_NGINX_IMAGE || ([ $OPT_HTTPD ] && echo $KUSANGI_HTTPD_IMAGE))
# create docker-compose.yml
env PROFILE=$PROFILE \
    HTTPD_IMAGE=$IMAGE \
    KUSANAGI_PHP7_IMAGE=$KUSANAGI_PHP7_IMAGE \
    CONFIG_IMAGE=$WPCLI_IMAGE \
    CERTBOT_IMAGE=$CERTBOT_IMAGE \
    HTTP_PORT=$HTTP_PORT \
    HTTP_TLS_PORT=$HTTP_TLS_PORT \
	envsubst '$$PROFILE $$HTTPD_IMAGE
	$$KUSANAGI_PHP7_IMAGE $$KUSANAGI_FTPD_IMAGE
	$$CONFIG_IMAGE $$CERTBOT_IMAGE
	$$HTTP_PORT $$HTTP_TLS_PORT' \
	< <(cat $LIBDIR/templates/docker.template $LIBDIR/templates/wpcli.template $LIBDIR/templates/php.template) > docker-compose.yml
if ! [ $NO_USE_DB ] ; then
	env PROFILE=$PROFILE KUSANAGI_MARIADB_IMAGE=$KUSANAGI_MARIADB_IMAGE \
	envsubst '$$PROFILE $$KUSANAGI_MARIADB_IMAGE' \
	< $LIBDIR/templates/mysql.template >> docker-compose.yml
fi
if ! [ $NO_USE_FTP ] ; then
    env PROFILE=$PROFILE KUSANAGI_FTPD_IMAGE=$KUSANAGI_FTPD_IMAGE  \
	envsubst '$$PROFILE $$KUSANAGI_FTPD_IMAGE' \
	< $LIBDIR/templates/ftpd.template >> docker-compose.yml
fi
echo >> docker-compose.yml
echo 'volumes:' >> docker-compose.yml
echo '  kusanagi:' >>  docker-compose.yml
[[ $DBHOST =~ ^localhost: ]] && echo '  database:' >> docker-compose.yml

function wp_lang() {
	if [ ${1} != "en_US" ] ; then
		k_configcmd $DOCUMENTROOT language core install ${WP_LANG} && \
		k_configcmd $DOCUMENTROOT language plugin install --all ${WP_LANG} && \
		k_configcmd $DOCUMENTROOT language theme install --all ${WP_LANG} && \
		k_configcmd $DOCUMENTROOT site switch-language ${WP_LANG} 
	fi
}

docker-compose up -d \
&& docker-compose run -u0 --rm config chown 1000:1001 /home/kusanagi  \
&& k_configcmd "/" chmod 751 /home/kusanagi \
&& k_configcmd "/" mkdir -p $DOCUMENTROOT || return 1
if [ "x$TARPATH" != "x" ] && [ -f $TARPATH ] ; then
	:
elif [  "x$GITPATH" != "x" ] && [ -f $GITPATH ] ; then 
	:
else

	if ! [ $NO_USE_DB ] ; then
		local ENTRY=1
		echo -n -e "\e[32m" $(eval_gettext "Waiting MySQL init process")
		while [ $ENTRY -eq 1 ] ; do
			echo -n "."
			sleep 5
			journalctl CONTAINER_NAME=${PROFILE}_db | tail -30 | grep "MySQL init process done. Ready for start up." > /dev/null
			ENTRY=$?
		done
		echo -e "\e[m"
	fi

	EXTRAPHP=$LIBDIR/wp/wp-config-sample/$WP_LANG/wp-config-extra.php
	[ -f $EXTRAPHP ] || EXTRAPHP=$LIBDIR/wp/wp-config-sample/en_US/wp-config-extra.php
	k_print_green "$(eval_gettext 'Provision WordPress')"
	k_configcmd $DOCUMENTROOT core download \
	&& sleep 1 \
	&& k_configcmd $DOCUMENTROOT core config \
		--dbhost=${DBHOST} \
		--dbname="${DBNAME}" --dbuser="${DBUSER}" --dbpass="${DBPASS}" \
		${DBPREFIX:+--dbprefix $DBPREFIX} \
		--dbcharset=${MYSQL_CHARSET:-utf8mb4} --extra-php < $EXTRAPHP \
	&& sleep 1 \
	&& k_configcmd $DOCUMENTROOT core install --url=http://${FQDN} \
		--title=${WP_TITLE} --admin_user=${ADMIN_USER} \
		--admin_password=${ADMIN_PASSWORD} --admin_email="${ADMIN_EMAIL}" \
	&& k_configcmd $DOCUMENTROOT chmod 440 wp-config.php \
	&& k_configcmd $DOCUMENTROOT mv wp-config.php .. \
	&& wp_lang $WP_LANG \
	&& tar cf - -C $LIBDIR/wp/ mu-plugins | k_configcmd $DOCUMENTROOT/wp-content tar xf - \
	&& tar cf - -C $LIBDIR/wp/ tools settings | k_configcmd $BASEDIR tar xf - \
	&& k_configcmd $DOCUMENTROOT mkdir -p ./wp-content/languages \
	&& k_configcmd $DOCUMENTROOT chmod 0750 . ./wp-content \
	&& k_configcmd $DOCUMENTROOT chmod -R 0770 ./wp-content/uploads \
	&& k_configcmd $DOCUMENTROOT chmod -R 0750 ./wp-content/languages ./wp-content/plugins \
	&& k_configcmd $BASEDIR sed -i "s/fqdn/$FQDN/g" tools/bcache.clear.php \
|| return 1
fi

#if [ $OPT_WOO ] ; then
#	k_configcmd "" theme install storefront
#	docker cp $PROFILE_httpd $KUSANAGILIBDIR/wp/wc4jp-gmo-pg.1.2.0.zip $PROFILE_httpd:$DOCUMENTROOT
#	k_configcmd "" unzip -q -d $DOCUMENTROOT/wp-content/plugins $DOCUMENTROOT/wc4jp-gmo-pg.1.2.0.zip
#	k_configcmd "" rm $DOCUMENTROOT/wc4jp-gmo-pg.1.2.0.zip
#	if [[ WP_LANG =~ ja ]] ; then
#		k_configcmd "" plugin install woocommerce-for-japan
#		k_configcmd "" language plugin install woocommerce-for-japan ja
#		k_configcmd "" language theme install storefront ja
#		k_configcmd "" plugin activate woocommerce-for-japan
#	fi
#	k_configcmd "" theme activate storefront
#	k_configcmd "" plugin activate wc4jp-gmo-pg
#
#fi

