#!/bin/bash

# How to use

# All commands are in quotes ("")!
# Set your API key, which can be found at https://manager.linode.com/profile with  "echo MY_API_KEY > .key"
# Get your Domain ID and your Resource ID
# For Domain ID run the command "./dyndns.sh list_domains" 
# For Resource ID run the command "./dyndns.sh list_resources DOMAIN_ID" - where DOMAIN_ID is the number from the command above!
# Do this for all the domains/resources you want to update. Tips: write them down as you go along :-)
# Then you have to create your domains and resource files.
# Like this : "echo xxx,yyy,zzz > .domains" and "echo aaa,bbb,ccc > .resources" where 'xxx,yyy...' and 'aaa,bbb...' are your domain and resource IDs
#
# Make a cron job with the script eg "crontab -e" with the command "0,30       *   *   *   *   /path/to/script/dyndns.sh update"
# The entry above will run the script once every 30 minutes.
#
# To get a list of your active domain and resource IDs and active IP run the command "./dyndns.sh dns_info"
#
# Original script by Andrew Childs (https://github.com/andrewchilds/linode-dyn-dns)
# Modified by Rune Gulbrandsøy (http://ghostblog.be)


##### NO CONFIGURATION NECESSARY.
declare -a DOMAINIDS
declare -a RESCOURCEIDS

MY_PATH="$( cd -P "$( dirname "$0" )" && pwd )"

MY_API_KEY=`cat $MY_PATH/.key 2>/dev/null`
DOMAIN=`cat $MY_PATH/.domains 2>/dev/null`
RESOURCE=`cat $MY_PATH/.resources 2>/dev/null`
LOG_FILE="$MY_PATH/dns.log"

CACHED_IP_FILE="$MY_PATH/.ip"

LINODE_API_URL="https://api.linode.com/?api_key=$MY_API_KEY"
IFS=',' read -a DOMAINIDS <<< "$DOMAIN"
IFS=',' read -a RESCOURCEIDS <<< "$RESOURCE"


##### IP FUNCTIONS

function get_ip {
	local IP=`curl --silent http://checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'`
	[ "$IP" == "" ] && {
		echo "[`date`] dyndns lookup failed, checking whatismyipaddress..." >> $LOG_FILE
		IP=`curl --silent http://bot.whatismyipaddress.com`
	}
	[ "$IP" == "" ] && {
		echo "[`date`] whatismyipaddress lookup failed, giving up." >> $LOG_FILE
		exit 1;
	}
	echo $IP
}

function get_cached_ip {
	cat $CACHED_IP_FILE 2>/dev/null
}



##### LINODE API HELPERS

# Retrieves a list of domains in your linode DNS manager.
function list_domains {
	echo $(curl --silent $LINODE_API_URL\&api_action=domain.list) | python -mjson.tool
}

# Retrieves a list of resources (i.e. subdomains) for a particular domain.
# @param Domain ID
function list_resources {
	[ $# -ne 1 ] && {
			echo "Usage: list_resources domain" 1>&2;
			exit 1;
	}
	echo $(curl --silent $LINODE_API_URL\&api_action=domain.resource.list\&DomainID=$1) | python -mjson.tool
}

# Updates a domain resource.
# @param Domain ID
# @param Resource ID
function update_resource_target {
	[ $# -ne 2 ] && {
			echo "Usage: update_resource_target domain resource" 1>&2;
			exit 1;
	}
	echo $(curl --silent -g $LINODE_API_URL\&api_action=domain.resource.update\&DomainID=$1\&ResourceID=$2\&TTL_sec=300\&Target=[remote_addr])
}

function update {
	IP_OLD=`get_cached_ip`
	IP_NEW=`get_ip`
	element_count=${#DOMAINIDS[@]}
	index=0
	[ "$IP_OLD" != "$IP_NEW" ] && [ "$IP_NEW" != "" ] && {
		while [ "$index" -lt "$element_count" ]
		do
		update_resource_target ${DOMAINIDS[$index]} ${RESCOURCEIDS[$index]}
		let "index = $index + 1"
		done
		echo "[`date`] IP changed from $IP_OLD to $IP_NEW" >> $LOG_FILE
	}

	[ "$IP_NEW" != "" ] && {
		echo $IP_NEW > $CACHED_IP_FILE
	}
}

function dns_info {
	IP=`get_cached_ip`
	echo "You have the following domainIDs: $DOMAIN and resourceIDs: $RESOURCE";
	echo "Your cached IP is: $IP";
	echo "Your log file is located here: $LOG_FILE";
	}

##### DO IT

$@
exit 0;