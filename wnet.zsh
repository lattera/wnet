#!/usr/local/bin/zsh

config="/home/shawn/projects/wnet/conf/networks.conf"
device="iwm0"
network=""
wlan="wlan0"
extraconfig=""
sleeptime=5

scan=""
randomize=0
ether=""

function main() {
	while getopts "rc:d:n:s:w:" o; do
		case "${o}" in
			c)
				config="${OPTARG}"
				;;
			d)
				device="${OPTARG}"
				;;
			n)
				network="${OPTARG}"
				;;
			r)
				randomize=1
				;;
			s)
				sleeptime=${OPTARG}
				;;
			w)
				wlan="${OPTARG}"
				;;
		esac
	done

	###################
	# Sanity checking #
	###################

	if [ -z ${network} ]; then
		echo "[-] Pass in the network, dummy!" >& 2
		exit 1
	fi

	if [ ! -f ${config} ]; then
		echo "[-] ${config} does not exist!" >& 2
		exit 1
	fi

	#################################
	# Fetch options for the network #
	#################################

	ssid=$(uclcmd get -f ${config} --noquotes .${network}.ssid)
	if [ "${ssid}" = "null" ]; then
		echo "[-] Network ${network} not found" >&2
		exit 1
	fi

	psk=$(uclcmd get -f ${config} --noquotes .${network}.psk)
	if [ "${psk}" = "null" ]; then
		echo "[-] Network ${network} has no psk" >&2
		exit 1
	fi

	scan=$(uclcmd get -f ${config} --noquotes .${network}.scan)
	if [ "${scan}" = "true" ]; then
		extraconfig="${extraconfig}\nscan_ssid=1"
	fi

	#######################################
	# If the interface exists, destroy it #
	#######################################

	ifconfig ${wlan} > /dev/null 2>&1
	if [ ${?} -eq 0 ]; then
		ifconfig ${wlan} destroy
		res=${?}
		if [ ${res} -gt 0 ]; then
			echo "[-] Could not destroy old ${wlan} interface" >&2
			exit 1
		fi
	fi

	############################
	# Create the new interface #
	############################

	ifconfig ${wlan} create wlandev ${device} ${ether}
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] Could not create ${wlan} device backed by ${device}" >&2
		exit 1
	fi

	if [ ${randomize} -gt 0 ]; then
		ifconfig ${wlan} ether random
		res=${?}
		if [ ${res} -gt 0 ]; then
			echo "[-] Could not set random MAC address" >&2
			exit 1
		fi
	fi

	cat <<EOF | wpa_supplicant -i ${wlan} -B -c /dev/stdin
network={
	ssid="${ssid}"
	psk="${psk}"
	${extraconfig}
}
EOF
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] wpa_supplicant failed" >&2
		exit 1
	fi

	####################################
	# Wait for the device to associate #
	####################################

	for ((i = 0; i < ${sleeptime}; i++)); do
		isup=$(ifconfig ${wlan} | grep '^[[:space:]]status:' | awk '{print $2;}')
		if [ ${isup} = "associated" ]; then
			break
		fi
		echo -n "."
		sleep 1
	done
	echo

	if [ ${isup} != "associated" ]; then
		echo "[-] Could not associate with network" 2>&1
		exit 1
	fi

	dhclient ${wlan}
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] dhclient failed" >&2
		exit 1
	fi
}

main $*
