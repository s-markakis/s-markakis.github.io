# Build: The Festival Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-event.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== Generated node config — the per-node values come first, the shared body follows =====
{
:local name "GATE-SW"
:local mgmt "10.80.99.11/24"
:local trunkPort "ether16"
:local vlans "10,20"
/system identity set name=$name
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port add bridge=bridge interface=$trunkPort frame-types=admit-only-vlan-tagged comment="backhaul"
/interface bridge vlan add bridge=bridge vlan-ids=$vlans tagged=($trunkPort . ",ether1,ether2")
/interface bridge vlan add bridge=bridge vlan-ids=99 tagged=("bridge," . $trunkPort)
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=$mgmt interface=v99-mgmt
/ip route add gateway=10.80.99.1
/system ntp client set enabled=yes servers=10.80.99.1
/system logging action add name=noc target=remote remote=10.80.99.5
/system logging add topics=warning action=noc
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
}
# ===== R1 — CCR2004 · trunk to the NOC switch, VLAN interfaces =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged
/interface bridge vlan add bridge=bridge vlan-ids=10,20,25,30,40,50,99 tagged=bridge,sfp-sfpplus1
/interface vlan
add name=v10-staff interface=bridge vlan-id=10
add name=v20-ticket interface=bridge vlan-id=20
add name=v25-pay interface=bridge vlan-id=25
add name=v30-prod interface=bridge vlan-id=30
add name=v40-press interface=bridge vlan-id=40
add name=v50-public interface=bridge vlan-id=50
add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.80.99.1/24 interface=v99-mgmt
# … .1 on each /24; the public /21 in step 4
/system ntp server set enabled=yes
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — DHCP and DNS sized for thousands of phones =====
/ip address add address=10.80.48.1/21 interface=v50-public
/ip pool add name=p-public ranges=10.80.48.10-10.80.55.250
/ip dhcp-server add name=d-public interface=v50-public address-pool=p-public lease-time=15m
/ip dhcp-server network add address=10.80.48.0/21 gateway=10.80.48.1 dns-server=10.80.48.1
# critical zones: small pools, reservations for every scanner and known till
/ip dhcp-server add name=d-ticket interface=v20-ticket address-pool=p-ticket lease-time=12h
/ip dhcp-server lease add server=d-ticket mac-address=00:24:2B:00:00:01 address=10.80.20.41 comment="scanner G-A-01"
# … the other zones the same way
/ip dns set allow-remote-requests=yes servers=208.67.222.222,208.67.220.220 cache-size=8192KiB \
    max-concurrent-queries=500
# ===== R1 — CAPsMAN: SSIDs per zone, matched by AP name =====
/interface wifi datapath
add name=dp-scan bridge=bridge vlan-id=20
add name=dp-pay bridge=bridge vlan-id=25
add name=dp-staff bridge=bridge vlan-id=10
add name=dp-press bridge=bridge vlan-id=40
add name=dp-public bridge=bridge vlan-id=50 client-isolation=yes
/interface wifi configuration
add name=cfg-scan ssid=EVT-SCAN security=sec-scan datapath=dp-scan country=Greece hide-ssid=yes
add name=cfg-pay ssid=EVT-PAY security=sec-pay datapath=dp-pay country=Greece hide-ssid=yes
add name=cfg-staff ssid=EVT-STAFF security=sec-staff datapath=dp-staff country=Greece hide-ssid=yes
add name=cfg-press ssid=FESTIVAL-Press security=sec-press datapath=dp-press country=Greece
add name=cfg-public ssid=FESTIVAL-Free datapath=dp-public country=Greece channel.width=20mhz
/interface wifi provisioning
add action=create-dynamic-enabled identity-regexp="^GATE-AP" master-configuration=cfg-scan slave-configurations=cfg-staff
add action=create-dynamic-enabled identity-regexp="^FOOD-AP" master-configuration=cfg-public slave-configurations=cfg-pay,cfg-staff
add action=create-dynamic-enabled identity-regexp="^STAGE-AP" master-configuration=cfg-press slave-configurations=cfg-staff
# ===== R1 — address lists and the forward chain =====
/ip firewall address-list
add list=TICKET-API address=api.tickets.example comment="from the ticketing company"
add list=PRESS-RX address=10.80.40.50 comment="feed receiver in the press tent"
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface=v99-mgmt
add chain=input action=accept in-interface-list=LAN protocol=udp dst-port=53,67,123
add chain=input action=accept in-interface-list=LAN protocol=tcp dst-port=53
add chain=input action=drop
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v20-ticket dst-address-list=TICKET-API protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v25-pay out-interface-list=WAN protocol=tcp dst-port=443 \
    comment="vendors bring their own terminals and acquirers: HTTPS out, nothing else"
add chain=forward action=accept in-interface=v30-prod dst-address-list=PRESS-RX protocol=udp dst-port=9000 \
    comment="program feed to the press tent (SRT)"
add chain=forward action=accept in-interface=v30-prod out-interface-list=WAN
add chain=forward action=accept in-interface=v10-staff out-interface-list=WAN
add chain=forward action=accept in-interface=v40-press out-interface-list=WAN
add chain=forward action=accept in-interface=v50-public out-interface-list=WAN
add chain=forward action=accept in-interface=v99-mgmt
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — WAN interfaces, probe routes kept current by DHCP scripts =====
/interface list member
add list=WAN interface=ether1
add list=WAN interface=ether2
add list=WAN interface=ether3
/ip route
add dst-address=1.1.1.1/32 gateway=100.64.0.1 scope=10 comment="probe A"
add dst-address=9.9.9.9/32 gateway=100.64.0.1 scope=10 comment="probe B"
/ip dhcp-client
add interface=ether1 add-default-route=no use-peer-dns=no comment="Starlink A" \
    script={ :if ($bound=1) do={ /ip route set [find comment="probe A"] gateway=$"gateway-address" } }
add interface=ether2 add-default-route=no use-peer-dns=no comment="Starlink B" \
    script={ :if ($bound=1) do={ /ip route set [find comment="probe B"] gateway=$"gateway-address" } }
add interface=ether3 add-default-route=no use-peer-dns=no comment="5G" \
    script={ :if ($bound=1) do={ /ip route set [find comment="crit via 5G"] gateway=$"gateway-address" } }
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# ===== R1 — one table per job, and rules that pick the table =====
/routing table
add name=crit fib
add name=prod fib
/ip route
# main (public, press): Starlink A only
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1
# crit (staff, scanners, tills): Starlink A, then 5G
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 routing-table=crit
add dst-address=0.0.0.0/0 gateway=100.64.0.1 distance=2 routing-table=crit comment="crit via 5G"
# prod (live stream): Starlink B, then Starlink A
add dst-address=0.0.0.0/0 gateway=9.9.9.9 target-scope=11 check-gateway=ping distance=1 routing-table=prod
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=2 routing-table=prod
/routing rule
add dst-address=10.80.0.0/16 action=lookup-only-in-table table=main comment="site stays on site"
add src-address=10.80.10.0/24 action=lookup table=crit
add src-address=10.80.20.0/24 action=lookup table=crit
add src-address=10.80.25.0/24 action=lookup table=crit
add src-address=10.80.30.0/24 action=lookup table=prod
# ===== R1 — one simple queue, per-phone limits inside it =====
/queue type
add name=pcq-pub-down kind=pcq pcq-classifier=dst-address pcq-rate=2M
add name=pcq-pub-up kind=pcq pcq-classifier=src-address pcq-rate=1M
/queue simple add name=public target=10.80.48.0/21 max-limit=8M/60M queue=pcq-pub-up/pcq-pub-down
# ===== R1 — a watch per zone and per line, logged to the NOC laptop =====
/tool netwatch
add host=10.80.99.11 interval=10s comment="GATE-SW" \
    down-script=":log warning \"ZONE GATES DOWN\"" up-script=":log warning \"ZONE GATES UP\""
add host=10.80.99.12 interval=10s comment="FOOD-SW" \
    down-script=":log warning \"ZONE FOOD DOWN\"" up-script=":log warning \"ZONE FOOD UP\""
add host=10.80.99.13 interval=10s comment="STAGE-SW" \
    down-script=":log warning \"ZONE STAGE DOWN\"" up-script=":log warning \"ZONE STAGE UP\""
add host=1.1.1.1 interval=15s down-script=":log warning \"STARLINK A DOWN\"" up-script=":log warning \"STARLINK A UP\""
add host=9.9.9.9 interval=15s down-script=":log warning \"STARLINK B DOWN\"" up-script=":log warning \"STARLINK B UP\""
/system logging action add name=noc target=remote remote=10.80.99.5
/system logging add topics=warning action=noc
# ===== Every node — keep the lessons, then return to the staging config =====
# on R1, before anything is unplugged
/log print file=festival-r1-log
/export file=festival-r1-final
# copy both files off to the NOC laptop, then on every node:
/system reset-configuration no-defaults=yes skip-backup=yes run-after-reset=flash/staging.rsc
