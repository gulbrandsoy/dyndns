#!/bin/bash

# How to use

# See the readme.md file

##### NO CONFIGURATION NECESSARY.
declare -a DOMAINIDS
declare -a RESCOURCEIDS

MY_PATH="$( cd -P "$( dirname "$0" )" && pwd )"

MY_API_KEY=`cat $MY_PATH/.key 2>/dev/null`
DOMAIN=`cat $MY_PATH/.domains 2>/dev/null`
RESOURCE=`cat $MY_PATH/.resources 2>/dev/null`
LOG_FILE="$MY_PATH/dns.log"

CACHED_IP_FILE="$MY_PATH/.ip"
CACHED_IPSIX_FILE="$MY_PATH/.ipsix"
LINODE_API_URL="https://api.linode.com/?api_key=$MY_API_KEY"
IFS=',' read -a DOMAINIDS <<< "$DOMAIN"
IFS=',' read -a RESCOURCEIDS <<< "$RESOURCE"


##### IP FUNCTIONS

function get_ip {
	local IP=`curl --silent http://ip4.iurl.no`
	[ "$IP" == "" ] && {
		echo "[`date`] iURL.no lookup failed, checking dyndns..." >> $LOG_FILE
	 	IP=`curl --silent http://checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'`
	}
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

function get_ip_six {
	IP_SIX=`curl --silent http://ip.iurl.no/`
	[[ -z "$IP_SIX" ]] && IP_SIX="N/A"
	[ "$IP_SIX" == "N/A" ] && IP_SIX=`curl --silent http://v6.ident.me/`
	[[ -z "$IP_SIX" ]] && IP_SIX="N/A"
	[ "$IP_SIX" == "N/A" ] && IP_SIX=`get_sec_ipsix`
	[[ -z "$IP_SIX" ]] && IP_SIX="N/A"
	echo $IP_SIX
}

function get_sec_ipsix {
	regex="(::|(([a-fA-F0-9]{1,4}):){7}(([a-fA-F0-9]{1,4}))|(:(:([a-fA-F0-9]{1,4})){1,6})|((([a-fA-F0-9]{1,4}):){1,6}:)|((([a-fA-F0-9]{1,4}):)(:([a-fA-F0-9]{1,4})){1,6})|((([a-fA-F0-9]{1,4}):){2}(:([a-fA-F0-9]{1,4})){1,5})|((([a-fA-F0-9]{1,4}):){3}(:([a-fA-F0-9]{1,4})){1,4})|((([a-fA-F0-9]{1,4}):){4}(:([a-fA-F0-9]{1,4})){1,3})|((([a-fA-F0-9]{1,4}):){5}(:([a-fA-F0-9]{1,4})){1,2}))"
	WEBPAGE=`curl --silent http://ipv6.whatismyv6.com`
	
	ipsixtwo=$(egrep -o -s "$regex" <<<"$WEBPAGE")
	echo $ipsixtwo
}
function get_cached_ip {
	cat $CACHED_IP_FILE 2>/dev/null
}

function get_cached_ip_six {
	cat $CACHED_IPSIX_FILE 2>/dev/null
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
	IP_NEW=`get_ip`
	# To force use of IPv4 leave the two next line as they are. To use IPv6 (if you broadcast that), switch the comment on the next two lines.
	
	#echo $(curl --silent -g $LINODE_API_URL\&api_action=domain.resource.update\&DomainID=$1\&ResourceID=$2\&TTL_sec=300\&Target=[remote_addr])
	echo $(curl --silent -g $LINODE_API_URL\&api_action=domain.resource.update\&DomainID=$1\&ResourceID=$2\&TTL_sec=300\&Target=$IP_NEW)
}

function update {
	IP_OLD=`get_cached_ip`
	IPSIX_OLD=`get_cached_ip_six`
	IP_NEW=`get_ip`
	IP_NEW_SIX=`get_ip_six`
	
	element_count=${#DOMAINIDS[@]}
	index=0
	[ "$IP_OLD" != "$IP_NEW" ] || [ "$IPSIX_OLD" != "$IP_NEW_SIX" ] && [ "$IP_NEW" != "" ] && {
		while [ "$index" -lt "$element_count" ]
		do
		update_resource_target ${DOMAINIDS[$index]} ${RESCOURCEIDS[$index]}
		let "index = $index + 1"
		done
		echo "[`date`] IP changed from $IP_OLD ($IPSIX_OLD) to $IP_NEW ($IP_NEW_SIX)" >> $LOG_FILE
	}

	[ "$IP_NEW" != "" ] && {
		echo $IP_NEW > $CACHED_IP_FILE
	}
	[ "$IP_NEW_SIX" != "" ] && {
		echo $IP_NEW_SIX > $CACHED_IPSIX_FILE
	}
}

function dns_info {
	IP=`get_cached_ip`
	IPSIX=`get_cached_ip_six`
	echo "You have the following domainIDs : $DOMAIN"; 
	echo "You have the following resourceIDs : $RESOURCE";
	echo "Your cached IPv4 : $IP"; 
	echo "Your cached IPv6 : $IPSIX";
	echo "Your log file is located here: $LOG_FILE";
	}

##### DO IT

$@
exit 0;