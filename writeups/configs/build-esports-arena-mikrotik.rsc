# Build: The Esports Arena Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-esports-arena.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== STAGE-SW — C9300-24UX · ports, SVIs, routed uplink =====
# STAGE-SW — CRS317-1G-16S+ as the pod's L3 switch: players, servers, referee
/system identity set name=STAGE-SW
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 pvid=10 comment="TEAM A seats 1-5 (sfp1-5)"
add bridge=bridge interface=sfp-sfpplus6 pvid=10 comment="TEAM B seats 1-5 (sfp6-10)"
add bridge=bridge interface=sfp-sfpplus11 pvid=15 comment="match servers (main, spare)"
add bridge=bridge interface=sfp-sfpplus13 pvid=20 comment="referee + capture-box mgmt"
/interface bridge vlan add bridge=bridge vlan-ids=10,15,20 tagged=bridge
# each player seat: exactly one MAC, pinned (= Cisco sticky port-security max 1)
/interface bridge port set [find interface=sfp-sfpplus1] learn=no
/interface bridge host add bridge=bridge interface=sfp-sfpplus1 \
    mac-address=00:11:22:00:10:01
# … one per seat
/interface vlan
add name=v10-players interface=bridge vlan-id=10
add name=v15-servers interface=bridge vlan-id=15
add name=v20-ops interface=bridge vlan-id=20
/ip address
add address=10.90.10.1/24 interface=v10-players
add address=10.90.15.1/24 interface=v15-servers
add address=10.90.20.1/24 interface=v20-ops
# the pod's only door: a routed /30 to CORE (a pure L3 port, not in the bridge)
/ip address add address=10.90.255.2/30 interface=sfp-sfpplus16
/ip route add gateway=10.90.255.1
# ===== BOOTCAMP-SW — C9300-48P =====
# BOOTCAMP-SW — CRS328-24P-4S+ (stacked): 42 practice PCs + servers on VLAN 11
/system identity set name=BOOTCAMP-SW
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="CORE"
add bridge=bridge interface=ether1 pvid=11 comment="bootcamp PCs + practice servers \
    (ether1-42)"
/interface bridge vlan
add bridge=bridge vlan-ids=11,99 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.90.99.14/24 interface=v99-mgmt
/ip route add gateway=10.90.99.1
# ===== PROD-SW — C9300-24UX · NDI-ready =====
# PROD-SW — CRS326-24S+2Q+: IGMP snooping and a querier on the bridge
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no igmp-snooping=yes \
    multicast-querier=yes
:for i from=1 to=14 do={ /interface bridge port add bridge=bridge \
    interface=("sfp-sfpplus" . $i) pvid=30 }
/interface bonding add name=bond-core slaves=sfp-sfpplus23,sfp-sfpplus24 mode=802.3ad
/interface bridge port add bridge=bridge interface=bond-core \
    frame-types=admit-only-vlan-tagged
/interface bridge vlan add bridge=bridge vlan-ids=30,99 tagged=bond-core
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== FOH-SW — C9200L-24P =====
# FOH-SW — CRS328-24P-4S+: arena AP trunks + press desks
/system identity set name=FOH-SW
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="CORE"
add bridge=bridge interface=ether1 pvid=99 comment="arena AP, local switching (ether1-8)"
add bridge=bridge interface=ether9 pvid=40 comment="press desk (ether9-16)"
/interface bridge vlan
add bridge=bridge vlan-ids=40,50,99 \
    tagged=sfp-sfpplus1,ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8
add bridge=bridge vlan-ids=99 tagged=bridge
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.90.99.13/24 interface=v99-mgmt
/ip route add gateway=10.90.99.1
# ===== CORE — C9300-48T · links, SVIs, routes =====
# CORE — CCR2116 as the L3 core: trunks, a routed link to the pod, SVIs, routes
/system identity set name=CORE
/interface bridge add name=bridge vlan-filtering=yes
/interface bonding add name=bond-prod slaves=sfp-sfpplus4,sfp-sfpplus5 mode=802.3ad \
    comment="PROD-SW"
/interface bridge port
add bridge=bridge interface=sfp-sfpplus3 frame-types=admit-only-vlan-tagged \
    comment="BOOTCAMP-SW"
add bridge=bridge interface=bond-prod frame-types=admit-only-vlan-tagged comment="PROD-SW"
add bridge=bridge interface=sfp-sfpplus6 frame-types=admit-only-vlan-tagged \
    comment="FOH-SW"
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="EDGE \
    (50,900)"
/interface bridge vlan
add bridge=bridge vlan-ids=11,99 tagged=bridge,sfp-sfpplus3
add bridge=bridge vlan-ids=30,99 tagged=bridge,bond-prod
add bridge=bridge vlan-ids=40,50,99 tagged=bridge,sfp-sfpplus6
add bridge=bridge vlan-ids=50,900 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=900 tagged=bridge
/interface vlan
add name=v11-bootcamp interface=bridge vlan-id=11
add name=v30-prod interface=bridge vlan-id=30
add name=v40-press interface=bridge vlan-id=40
add name=v99-mgmt interface=bridge vlan-id=99
add name=v900-transit interface=bridge vlan-id=900
/ip address
add address=10.90.11.1/24 interface=v11-bootcamp
add address=10.90.30.1/24 interface=v30-prod
add address=10.90.40.1/24 interface=v40-press
add address=10.90.99.1/24 interface=v99-mgmt
add address=10.90.254.2/29 interface=v900-transit
# the routed /30 to the stage pod (a pure L3 port)
/ip address add address=10.90.255.1/30 interface=sfp-sfpplus2
# the pod subnets are reached via STAGE-SW; the default goes to EDGE
/ip route add dst-address=10.90.10.0/24 gateway=10.90.255.2
/ip route add dst-address=10.90.15.0/24 gateway=10.90.255.2
/ip route add dst-address=10.90.20.0/24 gateway=10.90.255.2
/ip route add dst-address=0.0.0.0/0 gateway=10.90.254.1
# ===== DNS-ALLOW (10.90.20.53) — Unbound: every name is NXDOMAIN unless it's on the list =====
# Stage pod on MikroTik: a CRS312 switches the pod, a small CCR2004 routes it with a
# stateful firewall (software routing, but identical for both teams; measure it)
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v10-players out-interface=v15-servers \
    protocol=udp dst-port=27015-27020
add chain=forward action=accept in-interface=v10-players dst-address=10.90.20.53 \
    protocol=udp dst-port=53
add chain=forward action=drop in-interface=v10-players protocol=udp dst-port=53,853 \
    log=yes log-prefix=DNS-BYPASS
add chain=forward action=accept in-interface=v10-players out-interface=uplink protocol=tcp \
    dst-port=443
add chain=forward action=accept in-interface=uplink src-address=10.90.30.0/24 \
    out-interface=v15-servers \
    protocol=udp dst-port=27020 comment="observers: delayed spectator feed only"
add chain=forward action=accept in-interface=v20-ops
add chain=forward action=drop log=yes log-prefix=POD-DROP
# ===== STAGE-SW — SPAN all player and server ports to the capture box =====
# CRS3xx port mirroring: every player and server port copied to the capture box on ether24
/interface ethernet switch port set \
    ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9,ether10,ether11,ether12 \
    \
    mirror-ingress=yes mirror-egress=yes
/interface ethernet switch set switch1 mirror-ingress-target=ether24 \
    mirror-egress-target=ether24
# property names have changed across RouterOS 7 releases: check /interface ethernet switch print
# ===== Capture box — 10-minute files, 48 hours kept =====
# EDGE — RB5009: two ISPs, per-ISP NAT, tracked default, encoder-1 pinned to ISP B
/interface vlan add name=v900 interface=ether3 vlan-id=900
/interface vlan add name=v50-public interface=ether3 vlan-id=50
/ip address add address=10.90.254.1/29 interface=v900
/ip address add address=10.90.48.1/21 interface=v50-public
/ip address add address=203.0.113.10/29 interface=ether1 comment="ISP A"
/ip address add address=198.51.100.10/29 interface=ether2 comment="ISP B"
# a probe pinned to each ISP; default via A, B as the backup (check-gateway)
/ip route add dst-address=1.1.1.1/32 gateway=203.0.113.9 scope=10
/ip route add dst-address=9.9.9.9/32 gateway=198.51.100.9 scope=10
/ip route add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping \
    distance=1 comment="main: ISP A"
/ip route add dst-address=0.0.0.0/0 gateway=9.9.9.9 target-scope=11 check-gateway=ping \
    distance=2 comment="backup: ISP B"
/ip route add dst-address=10.90.0.0/16 gateway=10.90.254.2
# encoder 1 always leaves via ISP B while it is healthy (PBR via a routing mark)
/ip firewall mangle add chain=prerouting src-address=10.90.30.21 action=mark-routing \
    new-routing-mark=via-B passthrough=no
/ip route add dst-address=0.0.0.0/0 gateway=198.51.100.9 routing-mark=via-B \
    check-gateway=ping
# per-ISP source NAT
/ip firewall nat
add chain=srcnat out-interface=ether1 action=masquerade
add chain=srcnat out-interface=ether2 action=masquerade
# ===== EDGE — who may use which ISP (zone pairs) =====
# EDGE (CCR2116) — interface lists for zones, routing tables for "which ISP"
/routing table add name=isp-b fib
/routing table add name=isp-a-only fib
/ip route
add dst-address=0.0.0.0/0 gateway=203.0.113.9 distance=1 routing-table=isp-a-only
add dst-address=0.0.0.0/0 gateway=198.51.100.9 distance=1 routing-table=isp-b
/routing rule
add dst-address=10.90.0.0/16 action=lookup-only-in-table table=main
add src-address=10.90.30.21/32 action=lookup table=isp-b comment="encoder 1 on ISP \
    B"
add src-address=10.90.48.0/21 action=lookup-only-in-table table=isp-a-only \
    comment="public: ISP A or nothing"
# ===== EDGE — classify on the way in, queue on the way out =====
# EDGE — on RouterOS the gotcha doesn't exist: mangle in the forward chain
# runs before srcnat, so inside addresses are still visible when marking
/ip firewall address-list
add list=CRIT address=10.90.10.0/24
add list=CRIT address=10.90.15.0/24
add list=CRIT address=10.90.20.0/24
add list=CRIT address=10.90.30.22
/ip firewall mangle
add chain=forward action=mark-packet new-packet-mark=crit out-interface=ether1 \
    src-address-list=CRIT passthrough=no
add chain=forward action=mark-packet new-packet-mark=rest out-interface=ether1 \
    passthrough=no
/queue type add name=fq kind=fq-codel
/queue tree
add name=ISP-A parent=ether1 max-limit=475M
add name=crit parent=ISP-A packet-mark=crit priority=1 limit-at=285M max-limit=475M \
    queue=fq
add name=rest parent=ISP-A packet-mark=rest priority=8 max-limit=475M queue=fq
# ===== All devices — a known-good config, change logging, one-command rollback =====
# every device — baseline the night before, roll back by restoring it
/system backup save name=matchday-baseline dont-encrypt=no password=********
/export file=matchday-baseline
# risky change on match day: do it in Safe Mode (Ctrl+X), which undoes itself if you lose the session
# full rollback: /system backup load name=matchday-baseline.backup (reboots the device)
