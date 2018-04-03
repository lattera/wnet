wnet
====

This is just a little ZSH script to make it easy to specify which
exact wireless network you want to connect to. It uses Allan Jude's
uclcmd to parse a libucl config file.

Sample Config File
------------------

```
home {
	ssid: "MyHomeNetwork",
	psk: "NetworkPassword"
}

work {
	ssid: "WorkNetwork",
	psk: "WorkNetworkPassword",
	scan: true
}
```

Usage
-----

```
zsh ./wnet.zsh [-r] -c /path/to/config -n networkblock [-d device] \
    [-s sleeptime] [-w wlan]
```

Example with the config file above:

```
zsh ./wnet.zsh -c /etc/wnet.conf -n home
```
