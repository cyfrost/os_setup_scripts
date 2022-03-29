## Installation reference for pihole on an Rpi4_B running arm64 linux

these instructions are mostly for ubuntu (but they will work just as well on any other distro)...

most of these instructions are learnt from: https://github.com/pi-hole/docker-pi-hole/#running-pi-hole-docker

at the time of writing I have:

Hardware: Raspberry Pi 4 Model B (4GB RAM, Cortex A7, 64Bit CPU, aarch64 architecture)
OS: Ubuntu 21.04 (image available at https://ubuntu.com/download/raspberry-pi)
All OS updates done and build-essentials installed.

Router: TP-Link Archer C7 AC1750 (HW v5.0)
OS: OpenWrt 21.02 Stable (`OpenWrt 21.02.2 r16495-bf0c965af0 / LuCI openwrt-21.02 branch git-22.052.50801-31a27f3`)
Platform: `ath79/generic`

### Setting up pihole is done this way:

have an openwrt router or any router with any firmware. this router receives all your dns queries, but those are to be handled by pihole instead. pihole will be running on a seperate device (x86 or arm/+64), it will be part of your network via LAN or WIFI and have a static IP to it where pihole is always listening and ready to handle DNS queries.

once the above setup is ready, all that remains is to introduce pihole to openwrt so all DNS queries will be answered by ours truly henceforth.


**IMPORTANT NOTE**: I opened up my openwrt router config and assigned a static IP DHCP reservation for this raspberry pi: 192.168.1.227 (at the time of this writing), this is important because when you tell openwrt to use your raspberry pi (which runs your pihole), you need to supply a valid IP address pointing to it but if DHCP keeps changing the PI's IP on every DHCP lease change, it will break DNS resolution.

### Final Instructions

0. Modern releases of Ubuntu (17.10+) include systemd-resolved which is configured by default to implement a caching DNS stub resolver. This will prevent pi-hole from listening on port 53. The stub resolver should be disabled with: `sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf`. This will not change the nameserver settings, which point to the stub resolver thus preventing DNS resolution. Change the `/etc/resolv.conf` symlink to point to `/run/systemd/resolve/resolv.conf`, which is automatically updated to follow the system's netplan: `sudo sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'`. After making these changes, you should restart systemd-resolved using `sudo systemctl restart systemd-resolved`

1. install docker and docker compose from officail instructions, enable systemd service and socket and run hello-world and make sure docker is working.

2. we'll instlal pihole as a docker container (makes it easy to upgrade, maintain, and manage)...

3. create directory: `mkdir -p ~/my-pihole-docker-setup`

4. we'll use the readily available official docker images, to set it up, you need to download the template docker-compose config file from https://github.com/pi-hole/docker-pi-hole#readme 
 
5. create a `docker-compose.yml` file with the contents you lifted from the example in link above or use the following contents directly:

```
version: "3"

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    dns:
      - 127.0.0.1
      - 1.1.1.1
    # For DHCP it is recommended to remove these ports and instead add: network_mode: "host"
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp" # Only required if you are using Pi-hole as your DHCP server
      - "80:80/tcp"
    environment:
      TZ: '<<<<<<<<<<<your timezone goes here>>>>>>>>>>>>>>>>>>>>>'
      WEBPASSWORD: '<<<<<<<<<<<< webui password >>>>>>>>>>>>>>>>'
    # Volumes store your data between container upgrades
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'    
    #   https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
    cap_add:
      - NET_ADMIN # Recommended but not required (DHCP needs NET_ADMIN)      
    restart: unless-stopped
```

5. ensure the above settings are good enough for you and make changes as needed.

6. run `docker-compose up -d`

7. that's all, once this is set up and running, it will auto start on every boot automatically, no additional mucking required with writing custom systemd service unit files or anything...if docker starts at boot, so will all the containers, including our pihole one.

8. reboot once and make sure pihole is started and the dashboard is accessible via http://ipofyourpiholecomputerorrasperrypihere/admin/index.php

9. now all that remains is telling your openwrt router to **PROPERLY & RELIGIOUSLY** delegate DNS query handling to pihole, you can do that with these steps:

  - 9.1 openwrt LuCI -> uninstall or disable any services you installed by-hand that interfere with dns (examples: `https-dns-proxy` for DoH, etc) because they will break DNS resolution. reboot router once done.
  - 9.2 LuCI -> Network -> Interfaces -> lan/br-lan -> Advanced Settings -> ensure that `Use Custom DNS servers` is cleared and empty.
  - 9.3 LuCI -> Network -> Interfaces -> lan/br-lan -> DHCP Server -> Advanced Settings -> Under the `DHCP-Options` add new entry like `6,192.168.1.227` (make sure to replace that bogus IP with actual staic IP you assigned to your pihole host computer), and also make sure `Dynamic DHCP server` is enabled (which is the default anyway)
  - 9.4 LuCI -> Network -> Interfaces -> WAN -> Advanced Settings -> Uncheck the `Use DNS servers advertised by peer` option. this ensures clients' DNS queries will be blocked if they attempt to use Private DNS or any DNS server that is not our pihole.
  - 9.5 LuCI -> Network -> Interfaces -> WAN -> DHCP Server -> General Settings -> make sure the `Ignore interface` flag is checked true (which is the default anyway). simply because we do not want DHCP on WAN interface.
  - 9.6 LuCI -> Network -> DHCP and DNS -> General Settings -> Ensure that entries for `DNS Forwardsings` are empty.
  - 9.7 Sometimes DNS queries might leak through and not be handled by Pihole because of double NATting, this can only be prevented by adding custom rules to the openwrt firewall that force masquerading attempts and force redirect all DNS queries from WAN zone to your pihole. OpenWrt LuCI -> Network -> Firewall -> Custom Rules, add the following rules, copy pasta:
  ```
  iptables -t nat -A POSTROUTING -j MASQUERADE
  iptables -t nat -I PREROUTING -i br-lan -p tcp --dport 53 -j DNAT --to 192.168.1.227:53
  iptables -t nat -I PREROUTING -i br-lan -p udp --dport 53 -j DNAT --to 192.168.1.227:53
  iptables -t nat -I PREROUTING -i br-lan -p tcp -s 192.168.1.227 --dport 53 -j ACCEPT
  iptables -t nat -I PREROUTING -i br-lan -p udp -s 192.168.1.227 --dport 53 -j ACCEPT
  ```
  - 9.8, make sure you did the above steps right, reboot your router.

```
IMPORTANT: As discussed in https://old.reddit.com/r/pihole/comments/ooo8po/proper_openwrt_router_setup/, removing the WAN advertised DNS servers forcefully as described in the step 9.4 from above, that will probably prevent OpenWRT from being able to download software updates because it won't be able to get resolved domains. You can skip 9.4 and but the only gripe maybe that devices using private DNS will advertise them to openwrt and it will respect that instead of enforcing pihole, this may result in those devices escaping pihole's adblock capabilities but not a super huge issue unless most of your devices do advertise DNS servers other than the router's own so maybe it's ok to skip 9.4? YMMV
```


## Post-install best configuration for my pihole setup (adlists, etc)

login to the dashboard with whatever password you set in your docker-compose file.

`Dashboard -> Sidebar -> Group Management -> Adlists`, in the Add New List section, there's a text box, copy pasta below urls into it and hit save.

```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/cyfrost/dotfiles/master/dnsmasq_notracking_hosts.txt
https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts
https://v.firebog.net/hosts/static/w3kbl.txt
https://adaway.org/hosts.txt
https://v.firebog.net/hosts/AdguardDNS.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext
https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts
https://v.firebog.net/hosts/Easyprivacy.txt
https://v.firebog.net/hosts/Prigent-Ads.txt
https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts
https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt
https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt
https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt
https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
https://v.firebog.net/hosts/Admiral.txt
https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt
https://v.firebog.net/hosts/Easylist.txt
https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts
https://v.firebog.net/hosts/Prigent-Crypto.txt
https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt
https://phishing.army/download/phishing_army_blocklist_extended.txt
https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt
https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
https://urlhaus.abuse.ch/downloads/hostfile/
https://zerodot1.gitlab.io/CoinBlockerLists/
```
This will protect you from most bullshit trackers, privacy offenders, and most ads networks. it gives you a total of 2 million+ domains on blocklist.

Hit save, then go to `Sidebar -> Tools -> Update Gravity` and hit Update button, let it download all lists, parse them and prep its database for blocking.


#### Important pihole dashboard settings

Navigate to `Pihole Dashboard -> Sidebar -> Settings`

Under the `DNS` Tab:
  - clear and uncheck every dns server and only set `Cloudfare (DNSSEC` checked for IPV4 and IPV6. do NOT even have custom upstream dns servers, just cloudfare.
  - in the `Interface Settings` section -> select `Permit all origins`
  - scroll down to `Advanced DNS Settings` and check `Use DNSSEC` to true.
  - Enable `Conditional Forwarding` flag and enter the following details this way: Local Network in CIDR is: `192.168.1.0/24`, IP of DHCP server: `192.168.1.1`, Local domain name: `lan`
  hit save
  reboot pihole (or the machine that's running it).
  
  
 if everythings working and all clients are being handled, be proud of yourself :)




