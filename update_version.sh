#!/bin/bash

DOCKER_REPO=https://registry.hub.docker.com/v1/repositories
function docker_repo_tag {
	curl -s $DOCKER_REPO/${1}/tags | sed "s/,/\n/g" | awk -F\" '/name/ {print $4}'
}
function kusanagi_version {
	local _kusanagi=$1
	local _ver=$(docker_repo_tag primestrategy/${_kusanagi}-[0-9\.]+- | grep -v latest | sort -Vr | head -1)
	echo ${_ver:-latest}
}

function mariadb_version {
	local _ver=$(docker_repo_tag mariadb | grep '^[0-9\.]+-' | sort -Vr | head -1)
	echo ${_ver:-latest}
}
function postgresql_version {
	local _ver=$(docker_repo_tag postgres | grep '^[0-9\.]+-' | grep -v -e latest -e beta | sort -Vr | head -1)
	echo ${_ver:-latest}
}

function wpcli_version {
	local _ver=$(docker_repo_tag wordpress | grep '^cli-[0-9\.]+-' | grep -v -e latest -e beta | sort -r | head -1)
	echo ${_ver:-latest}
}

function certbot_version {
	local _ver=$(docker_repo_tag certbot/certbot | grep -v -e latest -e beta | sort -Vr | head -1)
	echo ${_ver:-latest}
}

KUSANAGILIBDIR=$HOME/.kusanagi/lib
KUSANAGI_NGINX_IMAGE=primestrategy/kusanagi-nginx:$(kusanagi_version kusanagi-nginx)
KUSANAGI_HTTPD_IMAGE=primestrategy/kusanagi-httpd:$(kusanagi_version kusanagi-httpd)
KUSANAGI_PHP_IMAGE=primestrategy/kusanagi-php:$(kusanagi_version kusanagi-php)
KUSANAGI_MYSQL_IMAGE=mariadb:$(mariadb_version)
KUSANAGI_CONFIG_IMAGE=primestrategy/kusanagi-config:$(kusanagi_version kusanagi-config)
KUSANAGI_FTPD_IMAGE=primestrategy/kusanagi-ftpd:$(kusanagi_version kusanagi-ftpd)
POSTGRESQL_IMAGE=postgres:$(postgresql_version)
WPCLI_IMAGE=wordpress:$(wpcli_version)
CERTBOT_IMAGE=certbot/certbot:$(certbot_version)

cat <<EOF > ${KUSANAGILIBDIR:-.}/image_versions
KUSANAGI_NGINX_IMAGE=$KUSANAGI_NGINX_IMAGE
KUSANAGI_HTTPD_IMAGE=$KUSANAGI_HTTPD_IMAGE
KUSANAGI_PHP_IMAGE=$KUSANAGI_PHP_IMAGE
KUSANAGI_MYSQL_IMAGE=$KUSANAGI_MYSQL_IMAGE
KUSANAGI_FTPD_IMAGE=$KUSANAGI_FTPD_IMAGE
KUSANAGI_CONFIG_IMAGE=$KUSANAGI_CONFIG_IMAGE
POSTGRESQL_IMAGE=$POSTGRESQL_IMAGE
WPCLI_IMAGE=$WPCLI_IMAGE
CERTBOT_IMAGE=$CERTBOT_IMAGE
EOF
