# Build: The Marina Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-marina.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-CORE — CRS328-24P-4S+ =====
/system identity set name=SW-CORE
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
# uplink to R1 (10G) + two fibre runs to the pontoon-head switches
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="R1"
add bridge=bridge interface=sfp-sfpplus2 frame-types=admit-only-vlan-tagged comment="ptA/B"
add bridge=bridge interface=sfp-sfpplus3 frame-types=admit-only-vlan-tagged comment="ptC/D"
# office access ports: staff on V10, the chandlery till on the payment V50
add bridge=bridge interface=ether1 pvid=10 comment="staff PCs"
add bridge=bridge interface=ether2 pvid=10 comment="berth-management server"
add bridge=bridge interface=ether3 pvid=10 comment="VoIP"
add bridge=bridge interface=ether8 pvid=50 comment="chandlery card terminal"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30,40,50 tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.80.99.11/24 interface=v99-mgmt
/ip route add gateway=10.80.99.1
# a quay is a public place: dead-end every unused jack
/interface ethernet disable ether9,ether10,ether11,ether12,ether13,ether14,ether15
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — CCR2004-16G-2S+ · bridge, VLAN gateways, DHCP, DNS =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="core"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30,40,50 tagged=bridge,sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/interface vlan
# one interface per VLAN = router-on-a-stick; each is that VLAN gateway
add name=v10-staff interface=bridge vlan-id=10
add name=v20-berth interface=bridge vlan-id=20
add name=v30-ot    interface=bridge vlan-id=30
add name=v40-cctv  interface=bridge vlan-id=40
add name=v50-pay   interface=bridge vlan-id=50
add name=v99-mgmt  interface=bridge vlan-id=99
/ip address
add address=10.80.10.1/24 interface=v10-staff
# /22 for berths: room for a full marina of boats plus their guests
add address=10.80.20.1/22 interface=v20-berth
add address=10.80.30.1/24 interface=v30-ot
add address=10.80.40.1/24 interface=v40-cctv
add address=10.80.50.1/24 interface=v50-pay
add address=10.80.99.1/24 interface=v99-mgmt
# the berth pool is handed out behind the hotspot (step 5); 1h leases
/ip pool add name=p-berth ranges=10.80.20.10-10.80.23.254
/ip dhcp-server add name=d-berth interface=v20-berth address-pool=p-berth lease-time=1h
/ip dhcp-server network add address=10.80.20.0/22 gateway=10.80.20.1 dns-server=10.80.20.1
# … staff, OT, CCTV and payment all use host reservations
/ip dns set allow-remote-requests=yes servers=9.9.9.9,149.112.112.112
/system ntp client set enabled=yes servers=time.cloudflare.com
/interface bridge set bridge vlan-filtering=yes
# ===== Pontoon A head — netPower 16P, fed by single-mode fibre =====
/system identity set name=SW-PONTOON-A
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
# fibre back to SW-CORE: no copper over the water, so no galvanic path
add bridge=bridge interface=sfp1 frame-types=admit-only-vlan-tagged comment="fibre to core"
# the sector AP rides a trunk: mgmt V99 untagged, berth SSID on V20
add bridge=bridge interface=ether1 pvid=99 comment="sector AP (PoE, trunk)"
# wired pontoon plant: shore-power pedestals (OT) and the pontoon-head camera
add bridge=bridge interface=ether2 pvid=30 comment="shore-power pedestals A"
add bridge=bridge interface=ether3 pvid=40 comment="pontoon-head camera"
/interface bridge vlan
add bridge=bridge vlan-ids=20,99 tagged=sfp1,ether1
add bridge=bridge vlan-ids=30,40 tagged=sfp1
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.80.99.21/24 interface=v99-mgmt
/ip route add gateway=10.80.99.1
# salt and lightning will kill this box one day; its config restores from the hub
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — CAPsMAN: an open berth SSID over the water, a hidden staff SSID =====
/interface wifi datapath
add name=dp-berth bridge=bridge vlan-id=20
add name=dp-staff bridge=bridge vlan-id=10
/interface wifi security
# berth SSID is OPEN — the hotspot (step 5) does the authentication, not WPA
add name=sec-open authentication-types="" disabled=no
add name=sec-staff authentication-types=wpa2-psk,wpa3-psk passphrase="********"
/interface wifi configuration
# 2.4 GHz: it reaches further over open water and bends around masts better than 5 GHz
add name=cfg-berth ssid=Marina-WiFi security=sec-open datapath=dp-berth country=Greece \
    .channel.band=2ghz-ax
add name=cfg-staff ssid=Marina-Staff security=sec-staff datapath=dp-staff country=Greece \
    hide-ssid=yes
/interface wifi capsman set enabled=yes interfaces=v99-mgmt
# the sector antennas point down the fairway; one config provisions every pontoon AP
/interface wifi provisioning
add action=create-dynamic-enabled supported-bands=2ghz-ax \
    master-configuration=cfg-berth slave-configurations=cfg-staff
# ===== R1 — Hotspot on V20, User Manager (RADIUS) on the same box =====
# the captive portal lives on the berth gateway
/ip hotspot profile
add name=marina hotspot-address=10.80.20.1 dns-name=wifi.marina login-by=http-chap,cookie \
    use-radius=yes
/ip hotspot add name=berth interface=v20-berth address-pool=p-berth profile=marina
# User Manager v5 is the RADIUS server, running on R1 itself → point RADIUS at loopback
/radius add service=hotspot address=127.0.0.1 secret="********"
/user-manager set enabled=yes
/user-manager/router add name=self address=127.0.0.1 shared-secret="********"
# a rate cap and a fair daily quota per boat; a week-long profile for a transient berth
/user-manager/limitation add name=lim-berth rate-limit=20M/5M
/user-manager/profile add name=berth-week name-for-users="7-day berth" validity=7d
/user-manager/profile-limitation add profile=berth-week limitation=lim-berth
# one voucher per slip, printed at the office on arrival; the code is never logged
/user-manager/user add name=A17 password="<voucher>" shared-users=3
/user-manager/user add name=A17 attributes=... # bind to profile berth-week
# walled garden: the booking page and the card host stay reachable before login
/ip hotspot walled-garden
add dst-host=book.marina.example action=allow
add dst-host=*.acquirer.example action=allow
# ===== R1 — interface lists, input and forward chains =====
/interface list
add name=WAN
add name=MGMT
/interface list member
add list=MGMT interface=v99-mgmt
# a named host group: where the card terminals are allowed to talk
/ip firewall address-list
add list=ACQUIRER address=203.0.113.0/24 comment="card acquirer (example)"
/ip firewall filter
# input = TO the router; established back in, then judge only NEW
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept in-interface-list=MGMT
# berths reach the router only for DNS/DHCP and the hotspot portal
add chain=input action=accept in-interface=v20-berth protocol=udp dst-port=53,67
add chain=input action=accept in-interface=v20-berth protocol=tcp dst-port=53,64872,64873
add chain=input action=drop log=yes log-prefix=IN-DROP
# forward = THROUGH the router; default-deny at the end
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
# payment: the till VLAN reaches ONLY the acquirer, nothing on the LAN, nothing else out
add chain=forward action=accept in-interface=v50-pay dst-address-list=ACQUIRER \
    protocol=tcp dst-port=443
# staff run the marina: book boats, read the meters, watch the cameras
add chain=forward action=accept in-interface=v10-staff out-interface=v30-ot
add chain=forward action=accept in-interface=v10-staff out-interface=v40-cctv
add chain=forward action=accept in-interface=v10-staff out-interface-list=WAN
# OT and cameras reach only their own clouds (step 8 shapes them), never the LAN
add chain=forward action=accept in-interface=v30-ot out-interface-list=WAN
add chain=forward action=accept in-interface=v40-cctv out-interface-list=WAN
# berths: the internet and nothing else — and never each other
add chain=forward action=accept in-interface=v20-berth out-interface-list=WAN
add chain=forward action=accept in-interface-list=MGMT
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — fibre primary, 5G backup, failover by recursive route =====
/interface list member add list=WAN interface=ether1
/interface list member add list=WAN interface=ether2
/ip dhcp-client add interface=ether1 add-default-route=no use-peer-dns=no comment="fibre"
# 5G as a passthrough modem; its default route sits at a worse distance (backup)
/ip dhcp-client add interface=ether2 default-route-distance=2 use-peer-dns=no comment="5G"
/ip route
# recursive main route: reachable only while the probe through fibre answers
add dst-address=1.1.1.1/32 gateway=ether1 scope=10 comment="probe via fibre"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 \
    comment="main: fibre"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# on 5G, the hotspot (berth Wi-Fi) is throttled hard; staff, payments and VoIP are not
/ip firewall mangle add chain=forward action=mark-packet new-packet-mark=berth-5g \
    in-interface=v20-berth out-interface=ether2 passthrough=no
/queue tree add name=berth-on-5g parent=global packet-mark=berth-5g max-limit=15M \
    queue=pcq-download-default
# ===== R1 — CAKE for the berths, priority for VoIP and card auth =====
# CAKE shares the fibre fairly per host first: one busy boat cannot starve the others
/queue type
add name=cake-up kind=cake cake-diffserv=diffserv4 cake-nat=yes cake-flowmode=dual-srchost
add name=cake-down kind=cake cake-diffserv=diffserv4 cake-flowmode=dual-dsthost
/ip firewall mangle
# lift VoIP and card-auth into the priority tin so a full hotspot never delays them
add chain=prerouting action=change-dscp new-dscp=46 src-address=10.80.10.0/24 \
    protocol=udp dst-port=10000-20000 comment="VoIP RTP"
add chain=prerouting action=change-dscp new-dscp=34 src-address=10.80.50.0/24 \
    comment="card auth"
add chain=forward action=mark-packet new-packet-mark=from-fibre in-interface=ether1 \
    passthrough=no
/queue tree
add name=wan-up parent=ether1 queue=cake-up max-limit=90M
add name=wan-down parent=global packet-mark=from-fibre queue=cake-down max-limit=450M
# ===== R1 — WireGuard to the operator hub, alerts and remote logs =====
/interface wireguard add name=wg-ops listen-port=13231
/interface wireguard peers add interface=wg-ops comment="operator hub" \
    public-key="<hub public key>" endpoint-address=hub.example.net endpoint-port=51820 \
    allowed-address=10.251.0.0/24 persistent-keepalive=25s
/ip address add address=10.251.0.31/24 interface=wg-ops
/interface list member add list=MGMT interface=wg-ops
/system logging action add name=hub target=remote remote=10.251.0.1
/system logging add topics=warning action=hub
# watch the fibre path and every pontoon switch; a dead pontoon is a silent outage
/tool netwatch add host=1.1.1.1 interval=30s type=simple \
    down-script=":log warning \"fibre DOWN\"" up-script=":log warning \"fibre UP\""
/tool netwatch add host=10.80.99.21 interval=60s type=simple \
    down-script=":log warning \"Pontoon A offline\""
