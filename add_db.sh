#!/bin/bash

# EMCLI Add Database
# Created by Seth Miller 2013/07
# Version 1.0


# This script is used in conjuction with Oracle Enterprise Manager EMCLI to add database
# targets to Enterprise Manager. It has only been tested with version 12.1 and 12.2.
# This script will source two files. The location by default is the same directory.
# This script was designed specifically for a RAC target and will add the instance
# targets followed by the database target and assign all specified properties.

# The instance targets will be named <Instance Name>_<Friendly Cluster Name>.
# The database targets will be called <Database Name>_<Friendly Cluster Name>.

# If the DEBUG variable is set to any value, only the commands will be printed to screen.
# The actual emcli commands will not be executed. To set DEBUG, execute "export DEBUG=y"
# on the command line before executing this script. To unset DEBUG,
# execute "unset DEBUG" on the command line before executing this script.

ORACLE_HOME="/u01/app/oracle/middleware/wls"
OMS_HOME="$ORACLE_HOME/oms"
EMCLI="$OMS_HOME/bin/emcli"


# Source the properties for the targets to be added.
. $(dirname $0)/add_db.src

# Source the monitoring user (i.e. dbsnmp) password.
. $(dirname $0)/monitoring.pwd



# Help menu
function USAGE {
        [ -z "$1" ] || echo -e "\n$1"
	echo -e "\nThis script is used in conjuction with Oracle Enterprise Manager EMCLI to add database"
	echo -e "targets to Enterprise Manager. This script will source 'add_db.src' and 'monitoring.pwd'."
	echo -e "The location by default for these files is the same directory."
	echo -e "This script was designed specifically for a RAC target and will add the instance"
	echo -e "targets followed by the database target and assign all specified properties.\n"
	echo -e "      usage: $(basename $0) -h"
	echo -e "description: Display this help menu.\n"
	echo -e "      usage: $(basename $0) -d"
	echo -e "description: Add database instance targets only.\n"
	echo -e "      usage: $(basename $0) -c"
	echo -e "description: Add cluster database target only.\n"
	echo -e "      usage: $(basename $0) -a"
	echo -e "description: Add database instance targets followed by cluster database targets.\n"
	exit 0
}

# Check to make sure user is logged into EMCLI. If not, allow user to login.
function CHECK_LOGIN
{
	$EMCLI sync > /dev/null && return
	read -p "You are not currently logged in. Login now? [y] " LOGIN_PROCEED 
	if [[ "$LOGIN_PROCEED" =~ "y|Y" || -z "$LOGIN_PROCEED" ]]; then
		read -p "Please provide a username " LOGIN_USERNAME
		$EMCLI login -username="$LOGIN_USERNAME"
	else
		exit 0
	fi
}

# Add the instance targets
function ADD_DBS
{
	for VARLEV1 in $(seq 0 $((${#INSTANCES[@]}-1))); do

		VAR=${INSTANCES[$VARLEV1]}
		SID_NUMBER=${VAR%:*}
		HOST=${VAR#*:}
		VIP=${HOST}-vip
		TARG_NAME=${DBNAME}${SID_NUMBER}_${CLUSTER}
		TARG_TYPE="oracle_database"

		# DEBUG
		echo -e "$EMCLI add_target -name=\"${TARG_NAME}\" -type=\"${TARG_TYPE}\" -host=\"${HOST}\" -credentials=\"UserName:${MONITORING_USER};password:<password>;Role:${CONNECT_AS}\" -properties=\"SID:${DBNAME}${SID_NUMBER};Port:${PORT};OracleHome:${ORACLE_HOME};MachineName:${VIP}\"\n"

		[ ! "$DEBUG" ] && \
		$EMCLI add_target -name="${TARG_NAME}" -type="${TARG_TYPE}" -host="${HOST}" -credentials="UserName:${MONITORING_USER};password:${MONITORING_PASSWORD};Role:${CONNECT_AS}" -properties="SID:${DBNAME}${SID_NUMBER};Port:${PORT};OracleHome:${ORACLE_HOME};MachineName:${VIP}"

		SET_PROPS "$TARG_NAME" "$TARG_TYPE"
	done
}

# Set the target properties on all of the targets
function SET_PROPS
{
	TARG_NAME="$1"
	TARG_TYPE="$2"

	for VARLEV2 in $(seq 0 $((${#PROP_ARR[@]}-1))); do

		# DEBUG
		echo -e "$EMCLI set_target_property_value -property_records=\"${TARG_NAME}:${TARG_TYPE}:${PROP_ARR[$VARLEV2]}\"\n"

		[ ! "$DEBUG" ] && \
		$EMCLI set_target_property_value -property_records="${TARG_NAME}:${TARG_TYPE}:${PROP_ARR[$VARLEV2]}"

	done
}

# Add the database targets
function ADD_CLUSTER
{
	for VARLEV3 in $(seq 0 $((${#INSTANCES[@]}-1))); do

		VAR=${INSTANCES[$VARLEV3]}
		SID_NUMBER=${VAR%:*}
		TARG_NAME=${DBNAME}${SID_NUMBER}_${CLUSTER}
		TARG_TYPE="oracle_database"

		if [ $VARLEV3 -eq 0 ]; then
			FAMILY="$TARG_NAME:$TARG_TYPE"
		else
			FAMILY="$FAMILY;$TARG_NAME:$TARG_TYPE"
		fi

	done

	TARG_NAME=${DBNAME}_${CLUSTER}
	TARG_TYPE="rac_database"
	HOST=${INSTANCES[0]#*:}

	# DEBUG
	echo -e "$EMCLI add_target -name=\"${TARG_NAME}\" -host=\"${HOST}\" -monitor_mode=1 -credentials=\"UserName:${MONITORING_USER};password:<password>;Role:${CONNECT_AS}\" -type=\"${TARG_TYPE}\" -properties=\"ServiceName:${SERVICE_NAME};ClusterName:${CLUSTER_NAME}\" -instances=\"${FAMILY}\"\n"

	[ ! "$DEBUG" ] && \
	$EMCLI add_target -name="${TARG_NAME}" -host="${HOST}" -monitor_mode=1 -credentials="UserName:${MONITORING_USER};password:${MONITORING_PASSWORD};Role:${CONNECT_AS}" -type="${TARG_TYPE}" -properties="ServiceName:${SERVICE_NAME};ClusterName:${CLUSTER_NAME}" -instances="${FAMILY}"

	SET_PROPS "$TARG_NAME" "$TARG_TYPE"
}


####################################################################################################
##		End of variable and function declarations
####################################################################################################


[ -z "$1" -o "$1" = "-h" -o "$1" = "-help" -o "$1" = "--help" ] && USAGE


# If the monitoring user password is not set in the
# MONITORING_PASSWORD variable, user will be prompted
# for it.
if [ ! "$MONITORING_PASSWORD" ]; then
	read -s -p "Enter the monitoring user password: " MONITORING_PASSWORD
	echo
fi

CHECK_LOGIN

[ "$DEBUG" ] && echo -e "\n=====================================\n==  The DEBUG variable is set to $DEBUG ==\n=====================================\n"


for CYCLE1 in $(seq 0 $((${#DBNAMES[@]}-1))); do

	DBNAME=${DBNAMES[$CYCLE1]%:*}
	SERVICE_NAME=${DBNAMES[$CYCLE1]#*:}

	if [ "$1" = "-d" ]; then

		ADD_DBS

	elif [ "$1" = "-c" ]; then

		ADD_CLUSTER

	elif [ "$1" = "-a" ]; then

		ADD_DBS
		ADD_CLUSTER

	fi

done
