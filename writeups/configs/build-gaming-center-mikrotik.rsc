# Build: The Gaming Center Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-gaming-center.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-SEATS — bridge, VLANs, seat ports =====
/system identity set name=SW-SEATS
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
# seats: untagged VLAN 10 only
:for i from=1 to=40 do={
  /interface bridge port add bridge=bridge interface=("ether" . $i) pvid=10 \
      frame-types=admit-only-untagged-and-priority-tagged
}
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="uplink R1"
add bridge=bridge interface=sfp-sfpplus2 pvid=10 comment="BOOT01 (step 2)"
add bridge=bridge interface=sfp-sfpplus3 pvid=10 comment="CACHE01 (step 2)"
/interface bridge vlan
add bridge=bridge vlan-ids=10 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=30 tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.30.99.11/24 interface=v99-mgmt
/ip route add gateway=10.30.99.1                 # R1 arrives in step 4
/interface ethernet disable ether41,ether42,ether43,ether44,ether45,ether46,ether47,ether48
# last, from the console port or in Safe Mode:
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== SW-SEATS — port isolation in the switch chip =====
:for i from=1 to=40 do={
  /interface ethernet switch port-isolation add port=("ether" . $i) \
      forwarding-override=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3
}
# ===== SW-FRONT — CRS328-24P-4S+ (PoE) =====
/system identity set name=SW-FRONT
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="uplink R1"
# … ether2-6: booths 2-6, same
add bridge=bridge interface=ether1 pvid=20 comment="booth 1"
add bridge=bridge interface=ether9 pvid=40 comment="POS PC"
add bridge=bridge interface=ether10 pvid=40 comment="card terminal"
add bridge=bridge interface=ether13 pvid=60 comment="cam 1"     # … ether14-20: cams 2-8
add bridge=bridge interface=ether21 pvid=60 comment="NVR"
add bridge=bridge interface=ether22 pvid=99 comment="cAP 1 (trunk)"
add bridge=bridge interface=ether23 pvid=99 comment="cAP 2 (trunk)"
add bridge=bridge interface=ether24 pvid=99 comment="cAP 3 (trunk)"
/interface bridge vlan
add bridge=bridge vlan-ids=20,40,60 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=40,50 tagged=sfp-sfpplus1,ether22,ether23,ether24
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.30.99.12/24 interface=v99-mgmt
/ip route add gateway=10.30.99.1
# cameras: no learning, only their own MAC may use the port
/interface bridge port set [find interface=ether13] learn=no
/interface bridge host add bridge=bridge interface=ether13 mac-address=AC:CC:8E:00:00:21
# … repeat per camera; then:
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — CCR2004-16G-2S+ · trunks and VLAN interfaces =====
/system identity set name=R1
/interface bridge add name=br-lan vlan-filtering=yes
/interface bridge port
add bridge=br-lan interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="SW-SEATS"
add bridge=br-lan interface=sfp-sfpplus2 frame-types=admit-only-vlan-tagged comment="SW-FRONT"
/interface bridge vlan
add bridge=br-lan vlan-ids=10,30 tagged=br-lan,sfp-sfpplus1
add bridge=br-lan vlan-ids=20,40,50,60 tagged=br-lan,sfp-sfpplus2
add bridge=br-lan vlan-ids=99 tagged=br-lan,sfp-sfpplus1,sfp-sfpplus2
/interface vlan
add name=v10-seats interface=br-lan vlan-id=10
add name=v20-consoles interface=br-lan vlan-id=20
add name=v30-srv interface=br-lan vlan-id=30
add name=v40-counter interface=br-lan vlan-id=40
add name=v50-guest interface=br-lan vlan-id=50
add name=v60-cctv interface=br-lan vlan-id=60
add name=v99-mgmt interface=br-lan vlan-id=99
/ip address
add address=10.30.10.1/24 interface=v10-seats
add address=10.30.20.1/24 interface=v20-consoles
add address=10.30.30.1/24 interface=v30-srv
add address=10.30.40.1/24 interface=v40-counter
add address=10.30.50.1/24 interface=v50-guest
add address=10.30.60.1/24 interface=v60-cctv
add address=10.30.99.1/24 interface=v99-mgmt
/interface list add name=LAN
/interface list member
add list=LAN interface=v10-seats
# … the same for every v* interface
# ===== R1 — DHCP with PXE options for the seats =====
/ip pool
add name=p-seats ranges=10.30.10.150-10.30.10.199   # spares; real seats use reservations
add name=p-consoles ranges=10.30.20.50-10.30.20.99
add name=p-counter ranges=10.30.40.50-10.30.40.99
add name=p-guest ranges=10.30.50.20-10.30.50.250
/ip dhcp-server
add name=d-seats interface=v10-seats address-pool=p-seats lease-time=12h
add name=d-consoles interface=v20-consoles address-pool=p-consoles lease-time=12h
add name=d-counter interface=v40-counter address-pool=p-counter lease-time=1d
add name=d-guest interface=v50-guest address-pool=p-guest lease-time=1h
/ip dhcp-server network
add address=10.30.10.0/24 gateway=10.30.10.1 dns-server=10.30.10.20 \
    next-server=10.30.10.10 boot-file-name=ipxe.efi comment="seats: PXE to BOOT01"
add address=10.30.20.0/24 gateway=10.30.20.1 dns-server=10.30.10.20
add address=10.30.40.0/24 gateway=10.30.40.1 dns-server=10.30.40.1
add address=10.30.50.0/24 gateway=10.30.50.1 dns-server=10.30.50.1
/ip dhcp-server lease
add server=d-seats mac-address=58:11:22:00:00:01 address=10.30.10.101 comment="Seat 1"
# … one reservation per seat; the diskless platform maps the same MAC to the seat number
/ip dns set allow-remote-requests=yes servers=1.1.1.2,1.0.0.2
# ===== R1 — address lists and filter rules =====
/ip firewall address-list
add list=CACHE address=10.30.10.20
add list=BOOT address=10.30.10.10
add list=POS address=10.30.40.10
add list=NVR address=10.30.60.10
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
# --- the router itself
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface=v99-mgmt comment="manage only from MGMT"
add chain=input action=accept in-interface-list=LAN protocol=udp dst-port=53,67
add chain=input action=accept in-interface-list=LAN protocol=tcp dst-port=53
add chain=input action=drop log=yes log-prefix=IN-DROP
# --- through the router
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept connection-nat-state=dstnat comment="UPnP mappings (step 7)"
add chain=forward action=accept in-interface=v10-seats out-interface-list=WAN comment="seats -> internet"
add chain=forward action=accept in-interface=v20-consoles dst-address-list=CACHE
add chain=forward action=accept in-interface=v20-consoles out-interface-list=WAN
add chain=forward action=accept in-interface=v40-counter out-interface-list=WAN
add chain=forward action=accept src-address-list=POS dst-address-list=BOOT protocol=tcp dst-port=443 \
    comment="staff console of the diskless platform (wake/restart seats)"
add chain=forward action=accept src-address-list=POS dst-address-list=NVR protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v50-guest out-interface-list=WAN
add chain=forward action=accept in-interface=v30-srv out-interface-list=WAN protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v99-mgmt
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — seats use the cache's DNS, nothing else =====
/ip firewall filter
add chain=forward action=drop in-interface=v10-seats protocol=udp dst-port=53,853 \
    place-before=[find comment="seats -> internet"] comment="no DNS bypass"
add chain=forward action=drop in-interface=v10-seats protocol=tcp dst-port=53,853 \
    place-before=[find comment="seats -> internet"]
# ===== R1 — WAN1, masquerade, UPnP on the console VLAN only =====
/interface list add name=WAN
/interface list member add list=WAN interface=ether1
/ip address add address=203.0.113.10/29 interface=ether1 comment="WAN1 fibre"
/ip route add gateway=203.0.113.9 comment="temporary, replaced in step 8"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN

/ip upnp set enabled=yes show-dummy-rule=no
/ip upnp interfaces
add interface=v20-consoles type=internal
add interface=ether1 type=external
# ===== R1 — WAN2, recursive failover, and a routing table for the cache =====
/interface pppoe-client add name=pppoe-wan2 interface=ether2 user=arena@isp2 password=******** \
    add-default-route=no use-peer-dns=no disabled=no
/interface list member add list=WAN interface=pppoe-wan2
/ip route remove [find comment="temporary, replaced in step 8"]
/ip route
add dst-address=1.1.1.1/32 gateway=203.0.113.9 scope=10 comment="probe via WAN1"
add dst-address=9.9.9.9/32 gateway=pppoe-wan2 scope=10 comment="probe via WAN2"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 comment="main: WAN1"
add dst-address=0.0.0.0/0 gateway=9.9.9.9 target-scope=11 check-gateway=ping distance=2 comment="main: WAN2"
# a second table where the preference is reversed
/routing table add name=via-wan2 fib
/ip route
add dst-address=0.0.0.0/0 gateway=9.9.9.9 target-scope=11 check-gateway=ping distance=1 routing-table=via-wan2
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=2 routing-table=via-wan2
/routing rule
add dst-address=10.30.0.0/16 action=lookup-only-in-table table=main comment="LAN stays LAN"
add src-address=10.30.10.20/32 action=lookup table=via-wan2 comment="cache downloads ride WAN2"
# ===== R1 — mangle and queue tree (WAN1) =====
/ip firewall mangle
add chain=forward action=mark-connection new-connection-mark=bulk protocol=tcp \
    connection-bytes=5000000-0 connection-mark=no-mark passthrough=yes comment="past 5 MB = a download"
add chain=forward action=mark-packet in-interface=ether1 connection-mark=bulk new-packet-mark=dl-bulk passthrough=no
add chain=forward action=mark-packet in-interface=ether1 new-packet-mark=dl-int passthrough=no
add chain=forward action=mark-packet out-interface=ether1 connection-mark=bulk new-packet-mark=ul-bulk passthrough=no
add chain=forward action=mark-packet out-interface=ether1 new-packet-mark=ul-int passthrough=no
/queue type
add name=pcq-down kind=pcq pcq-classifier=dst-address pcq-rate=0
add name=fq kind=fq-codel
/queue tree
add name=DOWN parent=global max-limit=950M
add name=down-int parent=DOWN packet-mark=dl-int priority=1 max-limit=950M queue=pcq-down
add name=down-bulk parent=DOWN packet-mark=dl-bulk priority=8 max-limit=950M queue=pcq-down
add name=UP parent=ether1 max-limit=190M
add name=up-int parent=UP packet-mark=ul-int priority=1 max-limit=190M queue=fq
add name=up-bulk parent=UP packet-mark=ul-bulk priority=8 max-limit=190M queue=fq
# ===== SW-SEATS — tournament on/off, scheduled =====
/system script
add name=tournament-on source={
  :local bracket "sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3"
  :for i from=1 to=10 do={ :set bracket ($bracket . ",ether" . $i) }
  :for i from=1 to=10 do={
    /interface ethernet switch port-isolation set [find port=("ether" . $i)] forwarding-override=$bracket
  }
  :log warning "TOURNAMENT ON: seats 1-10 can reach each other"
}
add name=tournament-off source={
  :for i from=1 to=10 do={
    /interface ethernet switch port-isolation set [find port=("ether" . $i)] \
        forwarding-override=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3
  }
  :log warning "TOURNAMENT OFF: seats 1-10 isolated again"
}
/system scheduler
add name=t-on start-date=2026-11-07 start-time=17:00:00 interval=7d on-event=tournament-on
add name=t-off start-date=2026-11-07 start-time=23:30:00 interval=7d on-event=tournament-off
# ===== R1 — CAPsMAN for three cAP ax (RouterOS 7 wifi) =====
/interface wifi security
add name=sec-guest authentication-types=wpa2-psk,wpa3-psk passphrase="rotate-me-monthly"
add name=sec-staff authentication-types=wpa2-psk,wpa3-psk passphrase="********"
# a datapath ties an SSID to its VLAN — that's the per-SSID isolation
/interface wifi datapath
add name=dp-guest bridge=bridge vlan-id=50 client-isolation=yes
add name=dp-staff bridge=bridge vlan-id=40
/interface wifi configuration
add name=cfg-guest ssid=ARENA-Guest security=sec-guest datapath=dp-guest country=Greece
add name=cfg-staff ssid=ARENA-Staff security=sec-staff datapath=dp-staff country=Greece hide-ssid=yes
# one controller pushes this Wi-Fi config to every AP
/interface wifi capsman set enabled=yes interfaces=v99-mgmt
/interface wifi provisioning
add action=create-dynamic-enabled supported-bands=5ghz-ax master-configuration=cfg-guest slave-configurations=cfg-staff
add action=create-dynamic-enabled supported-bands=2ghz-ax master-configuration=cfg-guest slave-configurations=cfg-staff

# 30 Mb/s for the whole lounge, split evenly per device
/queue simple add name=guest-wifi target=10.30.50.0/24 max-limit=30M/30M \
    queue=pcq-upload-default/pcq-download-default
# ===== R1 + both switches — management plane =====
/interface list add name=MGMT
/interface list member add list=MGMT interface=v99-mgmt
/ip service disable telnet,ftp,www,api,api-ssl
/ip service set ssh address=10.30.99.0/24
/ip service set winbox address=10.30.99.0/24
/tool mac-server set allowed-interface-list=MGMT
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/ip neighbor discovery-settings set discover-interface-list=MGMT
/user add name=netadmin group=full password=********
/user disable admin
/system ntp client set enabled=yes servers=time.cloudflare.com
/system logging action add name=remote target=remote remote=10.30.99.20
/system logging add topics=warning action=remote
/system logging add topics=firewall action=remote
/system scheduler add name=nightly-export interval=1d start-time=04:00:00 \
    on-event="/export show-sensitive file=nightly"
# ===== SW-SEATS + SW-FRONT — DHCP snooping =====
/interface bridge set bridge dhcp-snooping=yes
/interface bridge port set [find interface=sfp-sfpplus1] trusted=yes
