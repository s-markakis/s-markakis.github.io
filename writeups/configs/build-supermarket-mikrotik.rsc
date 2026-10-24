# Build: The Supermarket Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-supermarket.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== ACC-FRONT — C9200L-24P-4G · VLANs and lane ports =====
# ACC-FRONT — CRS328-24P-4S+: one known MAC per lane port, learning off
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
:for i from=1 to=16 do={
/interface bridge port add bridge=bridge interface=("ether" . $i) pvid=10 \
      learn=no \
frame-types=admit-only-untagged-and-priority-tagged comment="lane POS / PIN pad"
}
/interface bridge host add bridge=bridge interface=ether5 mac-address=00:13:C4:00:03:21   \
    # lane 3 PIN pad
# … one static host per lane device and per self-checkout (ether17-20)
/interface bridge port add bridge=bridge interface=ether21 pvid=40 \
    comment="signage"
/interface bridge vlan add bridge=bridge vlan-ids=10,40,50,99 tagged=sfp-sfpplus1
/interface ethernet disable ether22,ether23,ether24
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# a swapped PIN pad just gets no traffic forwarded: silent, not err-disabled (see the appendix)
# ===== ACC-BACK — C9200L-24P-4G =====
# ACC-BACK — CRS326-24G-2S+ : office, scales, ESL, refrigeration, PA
/system identity set name=ACC-BACK
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged \
    comment="uplink CORE"
add bridge=bridge interface=ether1 pvid=20 comment="OFFICE (ether1-4)"
add bridge=bridge interface=ether5 pvid=40 comment="deli/bakery/butcher scales (ether5-8)"
add bridge=bridge interface=ether9 pvid=40 comment="ESL base stations, PoE (ether9-14)"
add bridge=bridge interface=ether15 pvid=45 comment="refrigeration controller"
add bridge=bridge interface=ether16 pvid=40 comment="PA / music"
/interface bridge vlan
add bridge=bridge vlan-ids=20,40,45,99 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge
# refrigeration: pin its MAC, no learning (= Cisco sticky port-security)
/interface bridge port set [find interface=ether15] learn=no
/interface bridge host add bridge=bridge interface=ether15 mac-address=00:1B:44:00:45:10
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.50.99.21/24 interface=v99-mgmt
/ip route add gateway=10.50.99.1
# ===== SW-CCTV — C9200L-48P-4G =====
# SW-CCTV — CRS328-24P-4S+ : cameras + NVR, every camera MAC-pinned
/system identity set name=SW-CCTV
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged \
    comment="uplink CORE"
add bridge=bridge interface=ether1 pvid=60 comment="camera (ether1-24)"
add bridge=bridge interface=ether48 pvid=60 comment="NVR"
/interface bridge vlan
add bridge=bridge vlan-ids=60,99 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge
# cameras: no learning, one static MAC per port (= sticky port-security)
/interface bridge port set [find interface=ether1] learn=no
/interface bridge host add bridge=bridge interface=ether1 mac-address=AC:CC:8E:00:60:01
# … repeat per camera
/interface ethernet disable ether25,ether26,ether27,ether28,ether29,ether30
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.50.99.22/24 interface=v99-mgmt
/ip route add gateway=10.50.99.1
# ===== CORE — C9200-24T · port-channels and SVIs =====
# CORE — CRS328-24S+ as an L3 core: LACP bonds, SVIs, DHCP; guests routed by R1
/system identity set name=CORE
/interface bonding add name=bond1 slaves=ether1,ether2 mode=802.3ad comment="ACC-FRONT"
/interface bonding add name=bond2 slaves=ether3,ether4 mode=802.3ad comment="ACC-BACK"
/interface bonding add name=bond3 slaves=ether23,ether24 mode=802.3ad comment="SW-CCTV"
/interface bridge add name=bridge vlan-filtering=yes protocol-mode=rstp priority=0x1000
/interface bridge port
add bridge=bridge interface=bond1 frame-types=admit-only-vlan-tagged
add bridge=bridge interface=bond2 frame-types=admit-only-vlan-tagged
add bridge=bridge interface=bond3 frame-types=admit-only-vlan-tagged comment="cameras + \
    mgmt only"
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged \
    comment="R1-EDGE (50,900)"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30,40,45,99 tagged=bridge,bond1,bond2
add bridge=bridge vlan-ids=60,99 tagged=bond3
add bridge=bridge vlan-ids=50,900 tagged=bridge,sfp-sfpplus1
/interface vlan
add name=v10-cde interface=bridge vlan-id=10
add name=v20-office interface=bridge vlan-id=20
# … 30,40,45,60,99 the same; NO v50 (guests are routed by R1)
add name=v900-transit interface=bridge vlan-id=900
/ip address add address=10.50.10.1/24 interface=v10-cde
# … .1 on each VLAN
/ip address add address=10.50.255.2/29 interface=v900-transit
/ip dhcp-server add name=d-office interface=v20-office address-pool=p-office
/ip dhcp-server add name=d-handheld interface=v30-handheld address-pool=p-handheld \
    lease-time=12h
# store-iot: MAC reservations, same pattern
/ip route add gateway=10.50.255.1
# ===== ACC-FRONT Gi1/0/23-24 and ACC-BACK Gi1/0/21-24 — AP trunks =====
# ACC-FRONT (ether23-24) and ACC-BACK (ether21-24): AP trunk ports
# APs do local switching: handheld (30) + guest (50) tagged, mgmt (99) untagged
/interface bridge port
add bridge=bridge interface=ether23 pvid=99 comment="AP (local switching)"
add bridge=bridge interface=ether24 pvid=99 comment="AP (local switching)"
/interface bridge vlan
add bridge=bridge vlan-ids=30,50,99 tagged=sfp-sfpplus1,ether23,ether24
# ===== CORE — SVI ACLs (inbound) =====
# R1 (CCR2004) — routing moves off the core; the same policy as a stateful forward chain
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v10-cde out-interface-list=HQ \
    comment="CDE: HQ and nothing else"
add chain=forward action=drop in-interface=v10-cde log=yes log-prefix=CDE-OUT
add chain=forward action=drop out-interface=v10-cde log=yes log-prefix=CDE-IN \
    comment="nothing in the store reaches a till"
add chain=forward action=accept in-interface=v20-office out-interface-list=HQ
add chain=forward action=accept in-interface=v20-office out-interface=v40-iot protocol=tcp \
    dst-port=443
add chain=forward action=accept in-interface=v20-office dst-address=10.50.60.10 \
    protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v30-handheld dst-address=172.16.30.15 \
    protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v40-iot dst-address=172.16.40.0/24
add chain=forward action=accept in-interface=v45-refrig src-address=10.50.45.10 \
    dst-address=172.16.45.20 protocol=tcp dst-port=443
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1-EDGE — C8200L-1N-4T · LAN side =====
# R1-EDGE — RB5009: the guest VLAN and the transit to CORE live here
/interface vlan add name=v900 interface=ether3 vlan-id=900
/interface vlan add name=v50-guest interface=ether3 vlan-id=50
/ip address add address=10.50.255.1/29 interface=v900
/ip address add address=10.50.50.1/24 interface=v50-guest
/ip dhcp-server add name=d-guest interface=v50-guest address-pool=p-guest lease-time=2h
/ip dhcp-server network add address=10.50.50.0/24 gateway=10.50.50.1 \
    dns-server=9.9.9.9,149.112.112.112
# the whole store is reached through CORE; guests are the only locally-routed subnet
/ip route add dst-address=10.50.0.0/16 gateway=10.50.255.2
# guest total 20 Mb/s both ways
/queue simple add name=guest target=10.50.50.0/24 max-limit=20M/20M
# ===== CORE — uplink to R1 and the guest backstop =====
# CORE — the trunk down to R1 carries only guest (50) and transit (900)
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 \
    frame-types=admit-only-vlan-tagged comment="R1-EDGE"
/interface bridge vlan add bridge=bridge vlan-ids=50,900 tagged=sfp-sfpplus1,bridge
# backstop: a guest-sourced packet must never arrive on the transit interface
/ip firewall filter add chain=forward action=drop in-interface=v900-transit \
    src-address=10.50.50.0/24 \
    log=yes log-prefix=V900-DROP
/ip route add gateway=10.50.255.1
# ===== R1-EDGE — WAN, NAT and zones =====
# R1-EDGE — fibre, NAT only for office/store-iot/guest, and a default-deny egress
/ip address add address=203.0.113.42/29 interface=ether1 comment="FIBRE"
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.41
/ip firewall address-list
add list=NAT-SRC address=10.50.20.0/24
add list=NAT-SRC address=10.50.40.0/24
add list=NAT-SRC address=10.50.50.0/24
/ip firewall nat add chain=srcnat action=masquerade out-interface=ether1 \
    src-address-list=NAT-SRC
# office: any out; store-iot: HTTPS only; guest: any out. CDE/handheld/refrig/cctv: never.
/ip firewall filter
add chain=forward action=accept src-address=10.50.20.0/24 out-interface=ether1
add chain=forward action=accept src-address=10.50.40.0/24 out-interface=ether1 \
    protocol=tcp dst-port=443
add chain=forward action=accept src-address=10.50.50.0/24 out-interface=ether1 \
    comment="guest -> internet"
add chain=forward action=drop out-interface=ether1 log=yes log-prefix=INET-DROP
# ===== R1-EDGE — IKEv2 static VTI to HQ =====
# R1 — RouterOS has no static VTI: chains running MikroTik usually use WireGuard to HQ
/interface wireguard add name=wg-hq1 listen-port=13231
/interface wireguard peers add interface=wg-hq1 comment="HQ head-end 1" \
    public-key="<head-end 1 key>" \
endpoint-address=198.51.100.20 endpoint-port=51820 \
        allowed-address=172.16.0.0/16,10.255.142.0/30 \
    persistent-keepalive=25s
/ip address add address=10.255.142.2/30 interface=wg-hq1
/interface list member add list=HQ interface=wg-hq1
/ip route add dst-address=172.16.0.0/16 gateway=10.255.142.1 check-gateway=ping distance=1 \
    comment="HQ via fibre tunnel"
# IKEv2 + GRE is the alternative if HQ's head-ends must stay IPsec
# ===== R1-EDGE — what may cross the tunnel, in each direction =====
# R1-EDGE — exactly what crosses the WireGuard tunnel to HQ, each direction
/ip firewall address-list add list=HQ address=172.16.0.0/16
# STORE -> HQ (leaving via wg-hq1)
/ip firewall filter
add chain=forward action=accept out-interface=wg-hq1 src-address=10.50.10.0/24 \
    dst-address=172.16.0.0/16 comment="CDE -> HQ"
add chain=forward action=accept out-interface=wg-hq1 src-address=10.50.20.0/24 \
    dst-address=172.16.0.0/16
add chain=forward action=accept out-interface=wg-hq1 src-address=10.50.30.0/24 \
    dst-address=172.16.0.0/16
add chain=forward action=accept out-interface=wg-hq1 src-address=10.50.40.0/24 \
    dst-address=172.16.40.0/24
add chain=forward action=accept out-interface=wg-hq1 src-address=10.50.45.10 \
    dst-address=172.16.45.20 protocol=tcp dst-port=443
add chain=forward action=drop out-interface=wg-hq1 log=yes log-prefix=HQ-OUT
# HQ -> STORE (arriving on wg-hq1) — HQ is not trusted blindly
add chain=forward action=accept in-interface=wg-hq1 src-address=172.16.10.0/24 \
    dst-address=10.50.10.0/24 protocol=tcp dst-port=443 comment="POS mgmt"
add chain=forward action=accept in-interface=wg-hq1 src-address=172.16.10.0/24 \
    dst-address=10.50.10.0/24 protocol=tcp dst-port=22
add chain=forward action=accept in-interface=wg-hq1 src-address=172.16.40.0/24 \
    dst-address=10.50.40.0/24 protocol=tcp comment="price push to scales/ESL"
add chain=forward action=accept in-interface=wg-hq1 src-address=172.16.20.0/24 \
    dst-address=10.50.20.0/24 protocol=tcp dst-port=3389 comment="IT support"
add chain=forward action=accept in-interface=wg-hq1 src-address=172.16.60.0/24 \
    dst-address=10.50.60.10 protocol=tcp dst-port=443 comment="security viewing"
add chain=forward action=drop in-interface=wg-hq1 log=yes log-prefix=HQ-IN
# ===== R1-EDGE — probe, tracked default, LTE zone, standby tunnel =====
# R1 — second tunnel over LTE, pinned to its own head-end, standby by distance
/ip dhcp-client add interface=ether5 add-default-route=no use-peer-dns=no \
    comment="LTE passthrough"
/ip route add dst-address=198.51.100.21/32 gateway=ether5 comment="head-end 2 only \
    via LTE"
/interface wireguard add name=wg-hq2 listen-port=13232
/interface wireguard peers add interface=wg-hq2 comment="HQ head-end 2" \
    public-key="<head-end 2 key>" \
endpoint-address=198.51.100.21 endpoint-port=51820 \
        allowed-address=172.16.0.0/16,10.255.142.4/30 \
    persistent-keepalive=25s
/ip address add address=10.255.142.6/30 interface=wg-hq2
/interface list member add list=HQ interface=wg-hq2
/ip route add dst-address=172.16.0.0/16 gateway=10.255.142.5 check-gateway=ping distance=2 \
    comment="HQ via LTE tunnel"
# no default route via LTE at all: office and guests simply have no path to it
# ===== R1-EDGE — time-boxed, audited vendor access from HQ's jump host =====
# R1 — the firewall's time matcher does the window
/ip firewall filter add chain=forward action=accept src-address=172.16.5.10 \
    dst-address=10.50.45.10 \
    protocol=tcp dst-port=443 time=9h-12h,tue log=yes log-prefix=VENDOR \
place-before=[find log-prefix=FWD-DROP] comment="refrigeration vendor window"
/system logging action add name=hq target=remote remote=172.16.50.5
/system logging add topics=firewall action=hq
# ===== R1-EDGE — classify before encryption, shape the fibre upload =====
# R1 — WireGuard re-encapsulates, so queue the tunnel interface itself
/ip firewall mangle add chain=forward action=mark-packet new-packet-mark=crit \
    out-interface-list=HQ \
    src-address-list=CRITICAL passthrough=no
/ip firewall address-list
add list=CRITICAL address=10.50.10.0/24
add list=CRITICAL address=10.50.30.0/24
/queue tree
add name=hq parent=wg-hq1 max-limit=60M
add name=hq-crit parent=hq packet-mark=crit priority=1 limit-at=20M max-limit=60M
add name=hq-rest parent=hq packet-mark=no-mark priority=8 max-limit=60M
# ===== All devices — time and logging (PCI DSS requirement 10) =====
# All devices — NTP, remote syslog, login auditing (PCI DSS req. 10)
/system clock set time-zone-name=Europe/Athens
/system ntp client set enabled=yes servers=172.16.0.123
/system logging action add name=siem target=remote remote=172.16.50.5 bsd-syslog=yes
/system logging add topics=info action=siem
/system logging add topics=firewall action=siem
/system logging add topics=account action=siem
# keys are hidden from /export by default on RouterOS; keep backups off-box and encrypted
