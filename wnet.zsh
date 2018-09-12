#!/usr/local/bin/zsh

config="/home/shawn/projects/wnet/conf/networks.conf"
device="iwm0"
network=""
wlan="wlan0"
extraconfig=""
sleeptime=10

scan=""
randomize=0

function device_exists() {

	ifconfig ${wlan} > /dev/null 2>&1

	return ${?}
}

function destroy_device() {
	local res

	ifconfig ${wlan} destroy
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] Could not destroy old ${wlan} interface" >&2
		return 1
	fi

	return 0
}

function create_device() {
	local res

	ifconfig ${wlan} create wlandev ${device}
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] Could not create ${wlan} device backed by ${device}" >&2
		return ${res}
	fi

	if [ ${randomize} -gt 0 ]; then
		ifconfig ${wlan} ether random
		res=${?}
		if [ ${res} -gt 0 ]; then
			echo "[-] Could not set random MAC address" >&2
			return ${res}
		fi
	fi

	return 0
}

function list_networks() {
	local i
	local res

	if ! device_exists; then
		create_device
	fi

	ifconfig ${wlan} up
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] Could not bring the interface up for scanning"
		return 1
	fi

	echo "[*] Scanning for networks. Press ^C to stop."
	i=0
	while true; do
		if [ ${i} -gt 0 ]; then
			echo "==== ==== ==== ===="
		fi
		i=0
		ifconfig -v ${wlan} list scan |
		    awk -F 'SSID<' '{print $2;}' |
		    awk -F '>' '{print $1;}' | while read network; do
			if [ -z "${network}" ]; then
				continue
			fi
			
			echo "[${i}] ${network}"
			i=$((${i}+1))
		done

		echo "[*] Sleeping for ${sleeptime} seconds before the next scan."
		sleep ${sleeptime}
	done

	return 0
}

function main() {
	while getopts "lrc:d:n:s:w:" o; do
		case "${o}" in
			c)
				config="${OPTARG}"
				;;
			d)
				device="${OPTARG}"
				;;
			l)
				list_networks || exit ${?}
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
		extraconfig=$(echo "${extraconfig}\nscan_ssid=1")
	fi

	if device_exists; then
		if ! destroy_device; then
			exit ${?}
		fi
	fi

	############################
	# Create the new interface #
	############################

	create_device || exit 1

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
