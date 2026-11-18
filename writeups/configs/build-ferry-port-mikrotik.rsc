# Build: The Ferry Port Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-ferry-port.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== CORE-ADMIN — loopback and ring ports =====
/system identity set name=CORE-ADMIN
# a loopback is just an empty bridge with a /32 on it
/interface bridge add name=lo comment="router-id + management anchor"
/ip address add address=10.255.0.1/32 interface=lo
/interface ethernet
set sfp-sfpplus1 comment="RING to CORE-TERM"
set sfp-sfpplus2 comment="RING to CORE-TOWER"
set sfp-sfpplus3 comment="RING to CORE-CARGO (diagonal)"
# RouterOS 7 accepts /31 point-to-point addressing
/ip address
add address=10.255.1.0/31 interface=sfp-sfpplus1
add address=10.255.1.7/31 interface=sfp-sfpplus2
add address=10.255.1.8/31 interface=sfp-sfpplus3
# ===== CORE-ADMIN — OSPF process, area 0 on the ring =====
/routing ospf instance add name=ospf1 version=2 router-id=10.255.0.1
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf1
# no reference bandwidth on RouterOS: set the cost the Cisco side computes (10G = 10)
/routing ospf interface-template
add area=backbone interfaces=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3 \
    type=ptp cost=10
add area=backbone networks=10.255.0.1/32 passive
# ===== CORE-ADMIN — HMAC-SHA-256 key chain on every adjacency =====
# HMAC-SHA-256 on every adjacency-forming template (key id must match the Cisco key 1)
/routing ospf interface-template
set [find where !passive] auth=sha256 auth-id=1 auth-key="********"
# no TTL-security knob: drop OSPF from anything that isn't a ring port instead
/interface list add name=RING
/interface list member
add list=RING interface=sfp-sfpplus1
add list=RING interface=sfp-sfpplus2
add list=RING interface=sfp-sfpplus3
add list=RING interface=sfp-sfpplus4
/ip firewall filter
add chain=input protocol=ospf in-interface-list=!RING action=drop \
    comment="OSPF only on ring ports"
# ===== CORE-TERM — passenger terminal VLANs, SVIs and access trunk =====
/interface bridge add name=br-lan vlan-filtering=yes
/interface bridge port add bridge=br-lan interface=ether12 comment="TRUNK to ACC-TERM"
/interface bridge vlan add bridge=br-lan vlan-ids=101,102,103,104,105,115 \
    tagged=br-lan,ether12
/interface vlan
add name=vl101-staff interface=br-lan vlan-id=101
add name=vl103-ticketing interface=br-lan vlan-id=103
# ...and the same for 102, 104, 105 and 115
/ip address
add address=10.20.1.1/24 interface=vl101-staff
add address=10.20.3.1/24 interface=vl103-ticketing
# one passive template covers the whole building /20
/routing ospf interface-template add area=backbone networks=10.20.0.0/20 passive
/ip dhcp-relay add name=relay101 interface=vl101-staff dhcp-server=10.10.12.10 \
    local-address=10.20.1.1 disabled=no
# ===== EDGE1 — fibre, tracked default, NAT and default origination =====
/system identity set name=EDGE1
/ip address
add address=203.0.113.2/29 interface=ether1 comment="WAN fibre"
add address=10.255.1.11/31 interface=sfp-sfpplus1
# the default exists only while the ISP gateway answers
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.1 check-gateway=ping
/ip route add dst-address=10.0.0.0/8 blackhole comment="never leak 10/8"
/routing ospf instance add name=ospf1 router-id=10.255.0.11 \
    originate-default=if-installed out-filter-chain=ospf-out
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf1
/routing ospf interface-template add area=backbone interfaces=sfp-sfpplus1 \
    type=ptp cost=100 auth=sha256 auth-id=1 auth-key="********"
/routing filter rule add chain=ospf-out \
    rule="if (dst==0.0.0.0/0) { set ospf-ext-type type1; set ospf-ext-metric 10; accept }"
/ip firewall address-list
add list=nat-out address=10.10.12.0/24
add list=nat-out address=10.20.3.0/24
add list=nat-out address=10.30.6.0/24
# no wildcard masks on RouterOS; STAFF (.1) + VOICE (.2) are adjacent, so one range each
add list=nat-out address=10.10.1.0-10.10.2.255
add list=nat-out address=10.20.1.0-10.20.2.255
add list=nat-out address=10.30.1.0-10.30.2.255
add list=nat-out address=10.40.1.0-10.40.2.255
/ip firewall nat add chain=srcnat out-interface=ether1 src-address-list=nat-out \
    action=masquerade
# ===== EDGE2 — Starlink by DHCP, tracked, and a higher metric =====
/system identity set name=EDGE2
# Starlink in bypass mode hands out a CGNAT address by DHCP
/ip dhcp-client add interface=ether1 add-default-route=yes default-route-distance=100 \
    use-peer-dns=no check-gateway=ping
/routing ospf instance add name=ospf1 router-id=10.255.0.12 \
    originate-default=if-installed out-filter-chain=ospf-out
/routing filter rule add chain=ospf-out \
    rule="if (dst==0.0.0.0/0) { set ospf-ext-type type1; set ospf-ext-metric 100; accept }"
# ===== CORE-ADMIN — the link to EDGE1 (CORE-TOWER does the same towards EDGE2) =====
/routing bfd configuration
add interfaces=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 \
    min-rx=100ms min-tx=100ms multiplier=3
/routing ospf interface-template set [find where !passive] use-bfd=yes
# ===== YARD — IE-3400 in area 20 =====
/system identity set name=YARD
/ip address
add address=10.255.0.21/32 interface=lo
add address=10.255.1.15/31 interface=sfp-sfpplus1
/routing ospf instance add name=ospf1 version=2 router-id=10.255.0.21
/routing ospf area add name=yard area-id=0.0.0.20 type=stub instance=ospf1
/routing ospf interface-template
add area=yard interfaces=sfp-sfpplus1 type=ptp cost=100 use-bfd=yes \
    auth=sha256 auth-id=1 auth-key="********"
add area=yard networks=10.50.0.0/20,10.255.0.21/32 passive
# ===== CORE-CARGO — the ABR side: totally stubby and one summary =====
# on CORE-CARGO, the ABR
/routing ospf area add name=yard area-id=0.0.0.20 type=stub no-summaries=yes instance=ospf1
/routing ospf area range add area=yard prefix=10.50.0.0/20 advertise=yes
/routing ospf interface-template add area=yard interfaces=sfp-sfpplus4 type=ptp \
    cost=100 use-bfd=yes auth=sha256 auth-id=1 auth-key="********"
# ===== CORE-TERM — the terminal's SVI ACLs (CORE-ADMIN, CARGO, TOWER and YARD use the same ACL text) =====
# stateful, so the reply rules disappear: only who may START a connection
/ip firewall address-list
add list=cctv address=10.10.4.0/24
add list=cctv address=10.20.4.0/24
add list=cctv address=10.30.4.0/24
add list=cctv address=10.40.4.0/24
add list=cctv address=10.50.4.0/24
# CCTV (.4) and ACCESS (.5) are adjacent: one /23 per building covers both
add list=secot address=10.10.4.0/23
add list=secot address=10.20.4.0/23
add list=secot address=10.30.4.0/23
add list=secot address=10.40.4.0/23
add list=secot address=10.40.8.0/24 comment=VTS
add list=secot address=10.50.0.0/20 comment="the whole yard"
/ip firewall filter
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward src-address=10.10.12.30 dst-address-list=cctv action=accept \
    comment="NVR pulls the streams"
add chain=forward src-address-list=cctv dst-address=10.10.12.5 protocol=udp \
    dst-port=123 action=accept
add chain=forward src-address-list=cctv action=drop comment="cameras start nothing else"
add chain=forward in-interface=vl101-staff dst-address-list=secot action=drop
add chain=forward in-interface=vl101-staff action=accept
# ===== CORE-TOWER, CORE-CARGO, YARD — the segment-specific ACLs =====
/ip firewall filter
add chain=input connection-state=established,related action=accept
add chain=input connection-state=invalid action=drop
add chain=input in-interface=ether1 action=drop comment="nothing starts on the WAN"
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward src-address-list=nat-out out-interface=ether1 action=accept
add chain=forward action=drop comment="everything else, both directions"
# ===== All routers — stub-router behaviour after a reload =====
# no max-metric on RouterOS: drain a router by raising every adjacency's cost
/routing ospf interface-template set [find where !passive] cost=65535
# ...do the work, then put the real costs back
/routing ospf interface-template set [find where !passive] cost=10
# ===== All routers — time, logging, OSPF state traps, config archive =====
/system clock set time-zone-name=Europe/Athens
/system ntp client set enabled=yes servers=10.10.12.5
/system logging action add name=noc target=remote remote=10.10.12.20
/system logging add topics=ospf action=noc
/system logging add topics=info,!debug action=noc
/snmp community set [find default=yes] disabled=yes
/snmp community add name=noc security=private authentication-protocol=SHA1 \
    encryption-protocol=AES authentication-password="********" \
    encryption-password="********"
/snmp set enabled=yes trap-target=10.10.12.20 trap-version=3 trap-community=noc
