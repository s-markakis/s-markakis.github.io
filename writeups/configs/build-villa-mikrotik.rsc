# Build: The Holiday Villa Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-villa.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-UTIL — CRS328-24P-4S+ =====
/system identity set name=SW-UTIL
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
# trunk: admit-only-vlan-tagged rejects untagged frames on the uplink
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="uplink R1 (10G DAC)"
# pvid = the VLAN an access port's untagged traffic lands in
# … ether2-4: driveway, pool x2
add bridge=bridge interface=ether1 pvid=40 comment="camera gate"
add bridge=bridge interface=ether5 pvid=30 comment="alarm panel"
add bridge=bridge interface=ether6 pvid=30 comment="pool controller"
add bridge=bridge interface=ether7 pvid=30 comment="irrigation + gate"
add bridge=bridge interface=ether8 pvid=30 comment="smart-lock bridge"
# … ether10-12: bedroom TVs
add bridge=bridge interface=ether9 pvid=20 comment="TV living room"
add bridge=bridge interface=ether13 pvid=10 comment="owner's office"
/interface bridge vlan
# tagged= = the ports a VLAN leaves on tagged (here, the uplink)
add bridge=bridge vlan-ids=10,20,30,40 tagged=sfp-sfpplus1
# 'bridge' here = the switch's CPU, managed on V99
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
# the switch's address lives on MGMT only
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.70.99.11/24 interface=v99-mgmt
# just a default gateway (R1) so the switch is reachable
/ip route add gateway=10.70.99.1
/interface ethernet poe set ether5,ether6,ether7,ether8,ether9,ether10,ether11,ether12,ether13 poe-out=off
# disable unused ports — an open jack is an open door
/interface ethernet disable ether14,ether15,ether16,ether17,ether18,ether19,ether20,ether21,ether22,ether23,ether24
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== R1 — RB5009UPr+S+IN · bridge, trunks, VLAN interfaces, DHCP =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="SW-UTIL"
add bridge=bridge interface=ether3 pvid=99 comment="cAP ax living (trunk)"
add bridge=bridge interface=ether4 pvid=99 comment="cAP ax upstairs (trunk)"
add bridge=bridge interface=ether5 pvid=99 comment="pool wAP ax (trunk)"
add bridge=bridge interface=ether6 pvid=99 comment="wAP 60G house end (trunk to annex)"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30 tagged=bridge,sfp-sfpplus1,ether3,ether4,ether5,ether6
add bridge=bridge vlan-ids=40 tagged=bridge,sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/interface vlan
# one interface per VLAN = router-on-a-stick; each is that VLAN's gateway
add name=v10-owner interface=bridge vlan-id=10
add name=v20-guest interface=bridge vlan-id=20
add name=v30-home interface=bridge vlan-id=30
add name=v40-cctv interface=bridge vlan-id=40
add name=v99-mgmt interface=bridge vlan-id=99
/ip address          # the .1 of each subnet = the clients' gateway
add address=10.70.10.1/24 interface=v10-owner
add address=10.70.20.1/24 interface=v20-guest
add address=10.70.30.1/24 interface=v30-home
add address=10.70.40.1/24 interface=v40-cctv
add address=10.70.99.1/24 interface=v99-mgmt
# one pool + server + network per VLAN; guests get short leases
# 2h lease: a guest who leaves frees their address fast
/ip dhcp-server add name=d-guest interface=v20-guest address-pool=p-guest lease-time=2h
/ip dhcp-server network add address=10.70.20.0/24 gateway=10.70.20.1 dns-server=10.70.20.1
# … owner, smart home (reservations), CCTV (reservations), mgmt
/ip dns set allow-remote-requests=yes servers=9.9.9.9,149.112.112.112
/system ntp client set enabled=yes servers=time.cloudflare.com
/interface bridge set bridge vlan-filtering=yes
# ===== wAP 60G pair — a transparent bridge for the trunk =====
# house end
/interface w60g set wlan60-1 mode=bridge ssid=villa-annex password="********" frequency=auto disabled=no
/interface bridge add name=bridge
/interface bridge port add bridge=bridge interface=ether1
/interface bridge port add bridge=bridge interface=wlan60-1
# annex end: station-bridge; its ether1 feeds the annex cAP ax
# ===== R1 — CAPsMAN: guest, owner, and a 2.4 GHz smart-home SSID =====
/interface wifi security
add name=sec-guest authentication-types=wpa2-psk,wpa3-psk passphrase="replaced-at-every-checkout"
add name=sec-owner authentication-types=wpa2-psk,wpa3-psk passphrase="********"
add name=sec-home authentication-types=wpa2-psk passphrase="********"
# a datapath ties an SSID to its VLAN — guest Wi-Fi stays on V20, off the owner's V10
/interface wifi datapath
add name=dp-guest bridge=bridge vlan-id=20
add name=dp-owner bridge=bridge vlan-id=10
add name=dp-home bridge=bridge vlan-id=30
/interface wifi configuration
add name=cfg-guest ssid=VILLA-Guest security=sec-guest datapath=dp-guest country=Greece
add name=cfg-owner ssid=VILLA-Owner security=sec-owner datapath=dp-owner country=Greece hide-ssid=yes
add name=cfg-home ssid=VILLA-Home security=sec-home datapath=dp-home country=Greece hide-ssid=yes
# one controller pushes this Wi-Fi config to every AP
/interface wifi capsman set enabled=yes interfaces=v99-mgmt
# one radio carries the master SSID plus the slaves
/interface wifi provisioning
add action=create-dynamic-enabled supported-bands=5ghz-ax master-configuration=cfg-guest slave-configurations=cfg-owner
add action=create-dynamic-enabled supported-bands=2ghz-ax master-configuration=cfg-guest slave-configurations=cfg-owner,cfg-home
# ===== R1 — interface lists, input and forward chains =====
/interface list
add name=LAN
add name=WAN
add name=MGMT
/interface list member
add list=MGMT interface=v99-mgmt
# … every v* interface into LAN
/ip firewall address-list
# a named IP group (the four TVs) a rule can point at
add list=TVS address=10.70.20.31-10.70.20.34
# input = traffic TO the router; first match wins
/ip firewall filter
# established replies back in; the rest judges only NEW connections
add chain=input action=accept connection-state=established,related,untracked
# no known connection (malformed/spoofed) — drop early
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
# manage the router only from the MGMT VLAN
add chain=input action=accept in-interface-list=MGMT
add chain=input action=accept in-interface-list=LAN protocol=udp dst-port=53,67
# clients reach the router only for DNS/DHCP
add chain=input action=accept in-interface-list=LAN protocol=tcp dst-port=53
# default-deny: all not accepted above is dropped
add chain=input action=drop log=yes log-prefix=IN-DROP
# forward = traffic THROUGH the router (VLAN↔VLAN / internet)
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v10-owner out-interface=v30-home comment="owner's smart-home apps"
add chain=forward action=accept in-interface=v10-owner out-interface=v40-cctv comment="owner views cameras"
add chain=forward action=accept in-interface=v10-owner dst-address-list=TVS comment="owner casts to the TVs"
add chain=forward action=accept in-interface=v10-owner out-interface-list=WAN
add chain=forward action=accept in-interface=v20-guest out-interface-list=WAN
add chain=forward action=accept in-interface=v30-home out-interface-list=WAN
add chain=forward action=accept in-interface=v40-cctv out-interface-list=WAN
add chain=forward action=accept in-interface-list=MGMT
# default-deny between VLANs — this line is the isolation
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# let the owner's phone discover the TVs across VLANs (RouterOS 7.16+)
/ip dns set mdns-repeat-ifaces=v10-owner,v20-guest
# ===== R1 — Starlink on ether1, probe route maintained by the DHCP client =====
/interface list member add list=WAN interface=ether1
/ip route
add dst-address=1.1.1.1/32 gateway=100.64.0.1 scope=10 comment="probe via starlink"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 comment="main: starlink"
add dst-address=192.168.100.1/32 gateway=ether1 comment="dish status page"
/ip dhcp-client add interface=ether1 add-default-route=no use-peer-dns=no comment="Starlink (bypass)" script={
  :if ($bound=1) do={
    /ip route set [find comment="probe via starlink"] gateway=$"gateway-address"
  }
}
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# ===== R1 — 4G as distance 2, shaped for guests, closed to uploads =====
/ip dhcp-client add interface=ether2 default-route-distance=2 use-peer-dns=no comment="4G LtAP (passthrough)"
/interface list member add list=WAN interface=ether2
# cameras and smart-home clouds never use 4G
/interface list add name=NO4G
/interface list member
add list=NO4G interface=v30-home
add list=NO4G interface=v40-cctv
/ip firewall filter add chain=forward action=reject reject-with=icmp-network-unreachable \
    in-interface-list=NO4G out-interface=ether2 place-before=0 comment="no camera or IoT uploads on 4G"
# guests on 4G: 10 Mb/s down, 3 Mb/s up, shared fairly
/ip firewall mangle
add chain=forward action=mark-packet new-packet-mark=g4-down in-interface=ether2 out-interface=v20-guest passthrough=no
add chain=forward action=mark-packet new-packet-mark=g4-up in-interface=v20-guest out-interface=ether2 passthrough=no
/queue tree
add name=guest-4g-down parent=global packet-mark=g4-down max-limit=10M queue=pcq-download-default
add name=guest-4g-up parent=global packet-mark=g4-up max-limit=3M queue=pcq-upload-default
# ===== R1 — CAKE on the Starlink link =====
/queue type
add name=cake-up kind=cake cake-diffserv=diffserv4 cake-nat=yes cake-flowmode=dual-srchost
add name=cake-down kind=cake cake-diffserv=diffserv4 cake-flowmode=dual-dsthost
/ip firewall mangle add chain=forward action=mark-packet new-packet-mark=from-starlink \
    in-interface=ether1 passthrough=no
/queue tree
add name=starlink-up parent=ether1 queue=cake-up max-limit=20M
add name=starlink-down parent=global packet-mark=from-starlink queue=cake-down max-limit=180M
# ===== R1 — rotate the guest key and send it to the manager =====
/tool e-mail set server=smtp.mail.example port=587 tls=starttls user=villa-r1@mail.example password=********
/system script add name=rotate-guest-psk source={
  :local key [:rndstr length=14 from="abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789"]
  /interface wifi security set [find name=sec-guest] passphrase=$key
  /tool e-mail send to="manager@villa.example" subject="VILLA-Guest key for the next booking" \
      body=("Network: VILLA-Guest\nKey: " . $key . "\nPrint it on the welcome card.")
  :log warning "guest Wi-Fi key rotated"
}
/system scheduler add name=checkout-rotate start-date=2026-11-07 start-time=11:00:00 interval=7d \
    on-event=rotate-guest-psk
# ===== R1 — WireGuard to the operator's hub, alerts and remote logs =====
/interface wireguard add name=wg-ops listen-port=13231
/interface wireguard peers add interface=wg-ops comment="operator hub" public-key="<hub public key>" \
    endpoint-address=hub.example.net endpoint-port=51820 allowed-address=10.250.0.0/24 persistent-keepalive=25s
/ip address add address=10.250.0.21/24 interface=wg-ops
/interface list member add list=MGMT interface=wg-ops
/system logging action add name=hub target=remote remote=10.250.0.1
/system logging add topics=warning action=hub
/tool netwatch add host=1.1.1.1 interval=30s type=simple \
    down-script=":log warning \"Starlink path DOWN\"" up-script=":log warning \"Starlink path UP\""
