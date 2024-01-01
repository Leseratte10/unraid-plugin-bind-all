## Unraid plugin to bind services to all IPs

Starting with [Unraid 6.12.0](https://docs.unraid.net/unraid-os/release-notes/6.12.0/#network-improvements), users can configure the listening IPs for all services (WebUI, ssh, samba, etc.). Limetech calls it "listening interfaces", but that's not really the case - you can enter listening interfaces in the configuration (Settings -> Network Settings -> Interface Extra), but it's not actually configuring these services to only listen on these interfaces. 

Instead, Unraid loops through the given interfaces, saves all (or some, see below) IPs of these interfaces, then gives a list of IPs (not interfaces) to the services to listen on. 

This behaviour, however, has a ton of issues, and Unraid currently has no option to turn it off and switch back to the pre-6.12 behaviour. 

This plugin contains a modified version of the file `/etc/rc.d/rc.library.source` from an Unraid 6.12.6 installation which will always just return "::" and "0.0.0.0" as the listening IPs.

To use the plugin, make sure the "Included listening interfaces" and "Excluded listening interfaces" settings are both unset / empty, then install this plugin, then reboot the server. This should switch back all Unraid services to listen on :: (IPv6) and 0.0.0.0 (IPv4) again. 

The Unraid bug report where I reported this issue to hopefully get this either fixed, or a toggle setting added to switch back to the old behaviour, can be found [here](https://github.com/unraid/webgui/issues/1567). 

### Plugin warning

Note that I wrote down this whole plugin within a single evening, this is my first Unraid plugin ever created, and I still don't fully understand some of the networking changes done in 6.12.0. It's marked as being compatible with 6.12.0 to 6.12.6, but I've only tested it briefly on 6.12.6. 

Please only install this plugin if you have local GUI access (or access to the Flash Drive) to remove the plugin again if it breaks stuff, otherwise you might get locked out of your server.

### Issues with Unraid's new implementation

In Unraid 6.12, services no longer listen on ::, instead, they're only listening on hardcoded IP addresses. This causes multiple issues: 

- The code to determine the IPs to listen on is buggy. It seems to only use the first IPv4 and first IPv6 address of each network interface, instead of all of them. This means, if you're using IPv6 ULAs in your network to access the server, or you have a multi-homed IPv6 network, your setup will break, because the services will only be listening on the IPv4 address and the first found IPv6 GUA address. 

- When a service listens on :: (like in 6.11.x), there's no need for it to be notified / reloaded when the IPv6 prefix changes during operation. When a service is hardcoded to listen on a specific IPv6 address (like in 6.12.x), if the IPv6 network prefix changes, the services will not notice that change and will break (be unreachable over IPv6) until the services are manually restarted to pick up the new prefix. 

- According to [this forum post](https://forums.unraid.net/bug-reports/stable-releases/6125-unraid-services-not-listening-on-ipv6-addresses-r2749/) (I haven't checked this myself), when adding an IPv6 address to the list of listening interfaces, Unraid can confuse the last 16 bits of the IPv6 address with the port number in a service configuration. This obviously also makes that service unreachable.

- Unraid's implementation of `unmask` within the new code is broken - it assumes that every IPv6 network's size is /64 (which isn't too bad) and that every IPv4 network's size is /24 (which is bad). Not every network has these subnet sizes, however - if you're using IPv4 networks larger than /24, you may run into issues where only some clients (the one in the same /24; even though you might be running a /16) can reach the server. 

Now I get why Unraid made the changes they did - when it works correctly, it makes it fairly simple to configure if services should be reachable over which interfaces (Wireguard, Tailscale, other remote clients, ...). When it doesn't work correctly, however, it causes a bunch of issues - which is why I made this plugin.