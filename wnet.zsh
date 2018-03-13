#!/usr/local/bin/zsh

config="/home/shawn/projects/wnet/conf/networks.conf"
device="iwm0"
network=""
wlan="wlan0"

while getopts "c:d:n:w:" o; do
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
		wlan)
			wlan="${OPTARG}"
			;;
	esac
done

if [ -z ${network} ]; then
	echo "[-] Pass in the network, dummy!" >& 2
	exit 1
fi

if [ ! -f ${config} ]; then
	echo "[-] ${config} does not exist!" >& 2
	exit 1
fi

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

ifconfig ${wlan} create wlandev ${device}
res=${?}
if [ ${res} -gt 0 ]; then
	echo "[-] Could not create ${wlan} device backed by ${device}" >&2
	exit 1
fi

cat <<EOF | wpa_supplicant -i ${wlan} -B -c /dev/stdin
network={
	ssid="${ssid}"
	psk="${psk}"
}
EOF
res=${?}
if [ ${res} -gt 0 ]; then
	echo "[-] wpa_supplicant failed" >&2
	exit 1
fi

dhclient ${wlan}
res=${?}
if [ ${res} -gt 0 ]; then
	echo "[-] dhclient failed" >&2
	exit 1
fi
