#!/bin/bash

# Hestia Control Panel upgrade script for target version unreleased

#######################################################################################
#######                      Place additional commands below.                   #######
#######################################################################################
####### upgrade_config_set_value only accepts true or false.                    #######
#######                                                                         #######
####### Pass through information to the end user in case of a issue or problem  #######
#######                                                                         #######
####### Use add_upgrade_message "My message here" to include a message          #######
####### in the upgrade notification email. Example:                             #######
#######                                                                         #######
####### add_upgrade_message "My message here"                                   #######
#######                                                                         #######
####### You can use \n within the string to create new lines.                   #######
#######################################################################################

upgrade_config_set_value 'UPGRADE_UPDATE_WEB_TEMPLATES' 'true'
upgrade_config_set_value 'UPGRADE_UPDATE_DNS_TEMPLATES' 'true'
upgrade_config_set_value 'UPGRADE_UPDATE_MAIL_TEMPLATES' 'true'
upgrade_config_set_value 'UPGRADE_REBUILD_USERS' 'true'
upgrade_config_set_value 'UPGRADE_UPDATE_FILEMANAGER_CONFIG' 'false'

# Make sure to sync install quoteshell arg
if [ "$FILE_MANAGER" = "true" ]; then
	echo "[ * ] Force update filemanager..."
	$HESTIA/bin/v-delete-sys-filemanager quiet
	$HESTIA/bin/v-add-sys-filemanager quiet
fi

packages=$(ls --sort=time $HESTIA/data/packages | grep .pkg)
echo "[ * ] Update existing packages to support rate limit mail accounts..."
for package in $packages; do
	if [ -z "$(grep -e 'RATE_LIMIT' $HESTIA/data/packages/$package)" ]; then
		echo "RATE_LIMIT='200'" >> $HESTIA/data/packages/$package
	fi
done

if [ -z "$(grep -e 'condition =  ${lookup{$local_part@$domain}lsearch{/etc/exim4/domains/${lookup{$domain}dsearch{/etc/exim4/domains/}}/aliases}{false}{true}}' /etc/exim4/exim4.conf.template)" ]; then
	for line in $(sed -n '/redirect_router = dnslookup/=' /etc/exim4/exim4.conf.template); do
		testline=$((line - 1))
		newline=$((line + 1))
		if [ "$(awk NR==$testline /etc/exim4/exim4.conf.template)" = "  file_transport = local_delivery" ]; then
			# Add new line
			sed -i "$newline i \ \ condition = \${lookup{$local_part@\$domain}lsearch{/etc/exim4/domains/\${lookup{\$domain}dsearch{/etc/exim4/domains/}}/aliases}{false}{true}}" /etc/exim4/exim4.conf.template
		fi
	done
fi

# Allow Email@domain.com for login
if [ -f "/etc/dovecot/conf.d/10-auth.conf" ]; then
	sed -i "s/auth_username_format = %u/auth_username_format = %Lu/g" /etc/dovecot/conf.d/10-auth.conf
fi

# rename /var/run/xx to /run/
for file in /etc/dovecot/dovecot.conf /etc/clamav/clamd.conf /etc/exim/exim.conf.template /etc/logrotate.d/apache2 /etc/logrotate.d/nginx /etc/mysql/my.cnf /etc/nginx/nginx.conf; do
	if [ -f "$file" ]; then
		echo "[ * ] Update $file legacy /var/run/ to /run/"
		sed -i 's|/var/run/|/run/|g' $file
	fi
done
# Update any custom php templates
for file in $HESTIA/data/templates/web/php-fpm/*; do
	echo "[ * ] Update $file legacy /var/run/ to /run/"
	sed -i 's|/var/run/|/run/|g' $file
done

for file in /etc/php/*/fpm/pool.d/www.conf; do
	echo "[ * ] Update $file legacy /var/run/ to /run/"
	sed -i 's|/var/run/|/run/|g' $file
done

if echo "$BACKUP_SYSTEM" | grep "google" > /dev/null; then
	echo "[ ! ] Deprecation notice: Backup via Google Cloud has been removed setup backup again via Rclone to reinstate the backup and restore capebilities!"
	add_upgrade_message "Deprecation notice: Backup via Google Cloud has been removed setup backup again via Rclone to reinstate the backup and restore capebilities!"
fi
