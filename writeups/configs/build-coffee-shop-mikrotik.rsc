# Build: The Coffee Shop Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-coffee-shop.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-COUNTER — CRS112-8P-4S =====
/system identity set name=SW-COUNTER
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp1 frame-types=admit-only-vlan-tagged comment="R1 via S-RJ01 copper module"
add bridge=bridge interface=ether1 pvid=25 comment="card terminal 1"
add bridge=bridge interface=ether2 pvid=25 comment="card terminal 2"
add bridge=bridge interface=ether3 pvid=20 comment="receipt printer"
add bridge=bridge interface=ether4 pvid=30 comment="music streamer"
add bridge=bridge interface=ether5 pvid=30 comment="menu screen"
add bridge=bridge interface=ether6 pvid=40 comment="camera 1 (PoE)"
add bridge=bridge interface=ether7 pvid=40 comment="camera 2 (PoE)"
add bridge=bridge interface=ether8 pvid=40 comment="camera 3 (PoE)"
/interface bridge vlan
add bridge=bridge vlan-ids=20,25,30,40 tagged=sfp1
add bridge=bridge vlan-ids=99 tagged=bridge,sfp1
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.40.99.11/24 interface=v99-mgmt
/ip route add gateway=10.40.99.1
# only the cameras take power
/interface ethernet poe set ether1,ether2,ether3,ether4,ether5 poe-out=off
/interface ethernet disable sfp2,sfp3,sfp4
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== R1 — hAP ax³ · bridge, trunks, VLAN interfaces =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=ether2 frame-types=admit-only-vlan-tagged comment="SW-COUNTER trunk"
add bridge=bridge interface=ether3 pvid=99 comment="patio wAP trunk (mgmt untagged)"
add bridge=bridge interface=ether4 pvid=10 comment="office PC"
/interface bridge vlan
add bridge=bridge vlan-ids=10 tagged=bridge,ether3
add bridge=bridge vlan-ids=20 tagged=bridge,ether2,ether3
add bridge=bridge vlan-ids=25,30,40 tagged=bridge,ether2
add bridge=bridge vlan-ids=50 tagged=bridge,ether3
add bridge=bridge vlan-ids=99 tagged=bridge,ether2
/interface vlan
add name=v10-office interface=bridge vlan-id=10
add name=v20-pos interface=bridge vlan-id=20
add name=v25-pay interface=bridge vlan-id=25
add name=v30-iot interface=bridge vlan-id=30
add name=v40-cctv interface=bridge vlan-id=40
add name=v50-guest interface=bridge vlan-id=50
add name=v99-mgmt interface=bridge vlan-id=99
/ip address
add address=10.40.10.1/24 interface=v10-office
add address=10.40.20.1/24 interface=v20-pos
add address=10.40.25.1/24 interface=v25-pay
add address=10.40.30.1/24 interface=v30-iot
add address=10.40.40.1/24 interface=v40-cctv
add address=10.40.50.1/24 interface=v50-guest
add address=10.40.99.1/24 interface=v99-mgmt
# ===== R1 — DHCP and DNS (one pool + server + network per VLAN) =====
/ip pool
add name=p-pos ranges=10.40.20.50-10.40.20.99
add name=p-guest ranges=10.40.50.20-10.40.50.250
# … p-office, p-iot, p-cctv the same way
/ip dhcp-server
add name=d-pos interface=v20-pos address-pool=p-pos lease-time=1d
# reservations only
add name=d-pay interface=v25-pay address-pool=static-only lease-time=1d
add name=d-guest interface=v50-guest address-pool=p-guest lease-time=30m
/ip dhcp-server network
add address=10.40.20.0/24 gateway=10.40.20.1 dns-server=10.40.20.1
add address=10.40.25.0/24 gateway=10.40.25.1 dns-server=10.40.25.1
add address=10.40.50.0/24 gateway=10.40.50.1 dns-server=10.40.50.1
/ip dhcp-server lease
add server=d-pay mac-address=00:0B:4F:00:00:11 address=10.40.25.11 comment="card terminal 1"
add server=d-pay mac-address=00:0B:4F:00:00:12 address=10.40.25.12 comment="card terminal 2"
/ip dns set allow-remote-requests=yes servers=9.9.9.9,149.112.112.112
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — local radios + CAPsMAN for the patio wAP =====
/interface wifi security
add name=sec-pos authentication-types=wpa3-psk passphrase="********"
add name=sec-staff authentication-types=wpa2-psk,wpa3-psk passphrase="********"
# a datapath ties an SSID to its VLAN — that's the per-SSID isolation
/interface wifi datapath
add name=dp-guest bridge=bridge vlan-id=50 client-isolation=yes
add name=dp-pos bridge=bridge vlan-id=20
add name=dp-staff bridge=bridge vlan-id=10
/interface wifi configuration
add name=cfg-guest ssid=CAFE-Guest datapath=dp-guest country=Greece
add name=cfg-pos ssid=CAFE-POS security=sec-pos datapath=dp-pos country=Greece hide-ssid=yes
add name=cfg-staff ssid=CAFE-Staff security=sec-staff datapath=dp-staff country=Greece
# the router's own radios: guest on the master, POS and staff as virtual APs
/interface wifi set [find default-name=wifi1] configuration=cfg-guest disabled=no
/interface wifi add name=wifi1-pos master-interface=wifi1 configuration=cfg-pos disabled=no
/interface wifi add name=wifi1-staff master-interface=wifi1 configuration=cfg-staff disabled=no
# … the same three on wifi2 (2.4 GHz)
# the patio wAP is provisioned over its untagged management VLAN
# one controller pushes this Wi-Fi config to every AP
/interface wifi capsman set enabled=yes interfaces=v99-mgmt
/interface wifi provisioning add action=create-dynamic-enabled \
    master-configuration=cfg-guest slave-configurations=cfg-pos,cfg-staff
# ===== R1 — payment VLAN rules (first in the forward chain) =====
/ip firewall address-list
add list=ACQUIRER address=pay.acquirer.example comment="from the acquirer's integration guide"
add list=ACQUIRER address=tms.acquirer.example comment="terminal management + updates"
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v25-pay dst-address-list=ACQUIRER protocol=tcp dst-port=443 \
    comment="terminals -> acquirer only"
add chain=forward action=drop in-interface=v25-pay log=yes log-prefix=PAY-OUT comment="terminals -> anything else"
add chain=forward action=drop out-interface=v25-pay log=yes log-prefix=PAY-IN comment="nothing starts a connection into payments"
# ===== R1 — interface lists, input chain, the rest of forward =====
/interface list
add name=WAN
add name=LAN
add name=MGMT
/interface list member
add list=MGMT interface=v99-mgmt
add list=LAN interface=v10-office
# … v20-pos, v25-pay, v30-iot, v40-cctv, v50-guest, v99-mgmt into LAN as well
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface-list=MGMT
add chain=input action=accept in-interface-list=LAN protocol=udp dst-port=53,67
add chain=input action=accept in-interface-list=LAN protocol=tcp dst-port=53
add chain=input action=drop log=yes log-prefix=IN-DROP
# forward, after the payment rules from step 4
add chain=forward action=accept in-interface=v20-pos out-interface-list=WAN
add chain=forward action=accept in-interface=v10-office out-interface-list=WAN
add chain=forward action=accept in-interface=v30-iot out-interface-list=WAN
add chain=forward action=accept in-interface=v40-cctv out-interface-list=WAN
add chain=forward action=accept in-interface=v50-guest out-interface-list=WAN
add chain=forward action=accept in-interface=v10-office out-interface=v40-cctv protocol=tcp dst-port=443,554 \
    comment="owner views cameras on site"
add chain=forward action=accept in-interface-list=MGMT
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — hotspot on the guest VLAN, click-through ("trial") login =====
/ip hotspot user profile
add name=guest rate-limit=5M/5M idle-timeout=15m shared-users=1
/ip hotspot profile
add name=hs-cafe hotspot-address=10.40.50.1 dns-name=wifi.cafe.local html-directory=hotspot-cafe \
    login-by=trial trial-uptime-limit=2h trial-uptime-reset=1d trial-user-profile=guest
/ip hotspot add name=hs-guest interface=v50-guest address-pool=p-guest profile=hs-cafe disabled=no
/ip hotspot walled-garden add dst-host=menu.cafe.example comment="our own menu site works before login"
# ===== R1 — total guest cap with a queue tree (on top of the hotspot's per-device queues) =====
/ip firewall mangle
add chain=forward action=mark-packet in-interface=v50-guest new-packet-mark=guest-up passthrough=no
add chain=forward action=mark-packet out-interface=v50-guest new-packet-mark=guest-down passthrough=no
/queue tree
add name=guest-down parent=global packet-mark=guest-down max-limit=180M queue=pcq-download-default
add name=guest-up parent=global packet-mark=guest-up max-limit=30M queue=pcq-upload-default
# ===== R1 — PPPoE fibre, 4G passthrough, recursive failover, NAT =====
/interface pppoe-client add name=pppoe-fibre interface=ether1 user=cafe@isp password=******** \
    add-default-route=no use-peer-dns=no disabled=no
# backup route: used only when the primary is down (failover)
/ip dhcp-client add interface=ether5 default-route-distance=2 use-peer-dns=no comment="4G (LtAP passthrough)"
/interface list member
add list=WAN interface=pppoe-fibre
add list=WAN interface=ether5
/ip route
add dst-address=1.1.1.1/32 gateway=pppoe-fibre scope=10 comment="probe via fibre"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 comment="main: fibre"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# ===== R1 — the expensive line is for the tills =====
/interface list add name=NO4G
/interface list member
add list=NO4G interface=v30-iot
add list=NO4G interface=v40-cctv
add list=NO4G interface=v50-guest
/ip firewall filter add chain=forward action=reject reject-with=icmp-network-unreachable \
    in-interface-list=NO4G out-interface=ether5 place-before=0 comment="guests, cameras, IoT never use 4G"
# ===== R1 — mDNS repeater (RouterOS 7.16+) and the matching forward rules =====
/ip dns set mdns-repeat-ifaces=v20-pos,v30-iot,v10-office
/ip firewall address-list
add list=MUSIC address=10.40.30.20
add list=MENU address=10.40.30.21
/ip firewall filter
add chain=forward action=accept in-interface=v20-pos dst-address-list=MUSIC \
    place-before=[find log-prefix=FWD-DROP] comment="tablets control the music"
add chain=forward action=accept in-interface=v10-office dst-address-list=MUSIC \
    place-before=[find log-prefix=FWD-DROP] comment="owner's laptop controls the music"
add chain=forward action=accept in-interface=v20-pos dst-address-list=MENU protocol=tcp dst-port=443 \
    place-before=[find log-prefix=FWD-DROP] comment="tablets update the menu screen"
add chain=forward action=accept src-address-list=MUSIC out-interface=v20-pos protocol=tcp dst-port=3400-3401 \
    place-before=[find log-prefix=FWD-DROP] comment="speaker -> app events (vendor-specific)"
# ===== R1 — WireGuard client to the contractor's hub =====
/interface wireguard add name=wg-it listen-port=13231
/interface wireguard peers add interface=wg-it comment="IT hub" public-key="<hub public key>" \
    endpoint-address=hub.example.net endpoint-port=51820 allowed-address=10.250.0.0/24 persistent-keepalive=25s
/ip address add address=10.250.0.14/24 interface=wg-it
/interface list member add list=MGMT interface=wg-it
# ===== R1 (and the switch) — management plane and nightly backup =====
/ip service disable telnet,ftp,www,api,api-ssl
/ip service set ssh address=10.40.99.0/24,10.250.0.0/24
/ip service set winbox address=10.40.99.0/24,10.250.0.0/24
/tool mac-server set allowed-interface-list=MGMT
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/ip neighbor discovery-settings set discover-interface-list=MGMT
/user add name=netadmin group=full password=********
/user disable admin
/system ntp client set enabled=yes servers=time.cloudflare.com
/system scheduler add name=nightly interval=1d start-time=03:30:00 on-event={
  /export show-sensitive file=nightly
  :delay 5s
  /tool fetch upload=yes url="sftp://10.250.0.1/backups/cafe-r1.rsc" src-path=nightly.rsc \
      user=backup password=********
}
# on SW-COUNTER: only the uplink may answer DHCP
/interface bridge set bridge dhcp-snooping=yes
/interface bridge port set [find interface=sfp1] trusted=yes
