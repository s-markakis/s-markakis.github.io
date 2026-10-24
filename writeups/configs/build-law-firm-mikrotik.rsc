# Build: The Law Firm Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-law-firm.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== ACC-1 — C9200L-48P · VLANs and every endpoint port =====
# ACC-1 — CRS354-48P-4S+2Q+ (RouterOS 7)
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
:for i from=1 to=16 do={
  /interface bridge port add bridge=bridge interface=("ether" . $i) pvid=20 \
frame-types=admit-only-untagged-and-priority-tagged comment="desk (PC behind \
          phone)"
}
/interface bridge port add bridge=bridge interface=ether17 pvid=20 comment="reception \
    PC"
/interface bridge port add bridge=bridge interface=ether25 pvid=45 \
    comment="MFP-1"
:for i from=41 to=44 do={ /interface bridge port add bridge=bridge \
    interface=("ether" . $i) pvid=50 comment="meeting room" }
:for i from=33 to=40 do={ /interface bridge port add bridge=bridge \
    interface=("ether" . $i) pvid=60 learn=no comment="security" \
    }
/interface bridge host add bridge=bridge interface=ether33 mac-address=AC:CC:8E:00:00:21   \
    # one per camera
{
  :local t "sfp-sfpplus1"
  :for i from=1 to=16 do={ :set t ($t . ",ether" . $i) }
/interface bridge vlan add bridge=bridge vlan-ids=40 tagged=$t        # voice VLAN on the \
      desk ports
}
/interface bridge vlan add bridge=bridge vlan-ids=10,20,45,50,60 tagged=sfp-sfpplus1
/interface bridge vlan add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/ip neighbor discovery-settings set lldp-med-net-policy-vlan=40      # phones learn VLAN \
    40
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# no "port-security maximum 2": meeting ports rely on the guest VLAN having nowhere to go
# ===== AP switch ports (both floors) =====
# ACC-1/ACC-2 ether21-22 — AP trunks (mgmt untagged, lawyer/staff/guest tagged)
/interface bridge port
add bridge=bridge interface=ether21 pvid=99 comment="AP (local switching)"
add bridge=bridge interface=ether22 pvid=99 comment="AP (local switching)"
/interface bridge vlan add bridge=bridge vlan-ids=10,20,50,99 \
    tagged=sfp-sfpplus1,ether21,ether22
# ===== CORE — C9200-24T · VLANs, LACP to the floors, SVIs =====
# CORE — CRS326-24S+2Q+ as a Layer 2 core.
# The SVIs move to R1 (a CCR2004): MikroTik switches route in hardware, but not with a firewall
# on every inter-VLAN packet, which this design needs. See the appendix.
/interface bonding
add name=bond-acc1 slaves=sfp-sfpplus1,sfp-sfpplus2 mode=802.3ad \
    transmit-hash-policy=layer-2-and-3
add name=bond-acc2 slaves=sfp-sfpplus3,sfp-sfpplus4 mode=802.3ad \
    transmit-hash-policy=layer-2-and-3
/interface bridge add name=bridge vlan-filtering=no priority=0x1000      # STP root
/interface bridge port
add bridge=bridge interface=bond-acc1 frame-types=admit-only-vlan-tagged
add bridge=bridge interface=bond-acc2 frame-types=admit-only-vlan-tagged
add bridge=bridge interface=sfp-sfpplus24 frame-types=admit-only-vlan-tagged \
    comment="R1 (CCR2004)"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30,40,45,50,60,99 \
    tagged=bond-acc1,bond-acc2,sfp-sfpplus24
/interface bridge set bridge vlan-filtering=yes

# on R1 (CCR2004): one VLAN interface per routed VLAN replaces each Cisco SVI
/interface vlan add name=v10-lawyers interface=bridge vlan-id=10
/ip address add address=10.20.10.1/24 interface=v10-lawyers
# … the same for 20, 30, 40, 45, 60, 99
# ===== ACC-1 / ACC-2 — the matching uplink =====
# ACC-1/ACC-2 — LACP uplink to CORE (= Cisco Port-channel, native 666 parking)
/interface bonding add name=bond1 slaves=ether1,ether2 mode=802.3ad comment="to CORE"
/interface bridge port add bridge=bridge interface=bond1 \
    frame-types=admit-only-vlan-tagged
/interface bridge vlan add bridge=bridge vlan-ids=10,20,40,45,50,60,99 tagged=bond1
# ===== CORE — server ports and DHCP relay =====
# CORE — server ports on VLAN 30, and a DHCP relay to DC01 (10.20.30.10)
/interface bridge port
add bridge=bridge interface=ether5 pvid=30 comment="SERVERS: DC01 DMS01 FS01 NAS01 \
    (ether5-8)"
/interface bridge vlan add bridge=bridge vlan-ids=30 tagged=bridge
/interface vlan add name=v30-srv interface=bridge vlan-id=30
/ip address add address=10.20.30.1/24 interface=v30-srv
# relay each client VLAN's DHCP to DC01 (= Cisco ip helper-address)
/ip dhcp-relay
add name=r-lawyers interface=v10-lawyers dhcp-server=10.20.30.10 local-address=10.20.10.1
add name=r-staff interface=v20-staff dhcp-server=10.20.30.10 local-address=10.20.20.1
add name=r-voice interface=v40-voice dhcp-server=10.20.30.10 local-address=10.20.40.1
add name=r-print interface=v45-print dhcp-server=10.20.30.10 local-address=10.20.45.1
# ===== ACC-1 / ACC-2 — DHCP snooping, then DAI =====
# ACC-1/ACC-2 — DHCP snooping + ARP inspection. RouterOS does both on the bridge:
# add-arp=yes builds the ARP table from snooped leases, which is the DAI check.
/interface bridge set bridge dhcp-snooping=yes add-arp=yes
# only the uplink to CORE is trusted (the relay/real DHCP server is upstream)
/interface bridge port set [find interface=bond1] trusted=yes
# the AP ports carry many clients; keep them trusted so bursts don't trip the bridge
/interface bridge port set [find interface=ether21] trusted=yes
/interface bridge port set [find interface=ether22] trusted=yes
# ===== CORE — user-VLAN ACLs =====
# R1 (CCR2004) — the same policy as a STATEFUL forward chain
/ip firewall address-list
add list=DC address=10.20.30.10
add list=DMS address=10.20.30.20
add list=FS address=10.20.30.21
/interface list add name=USERS
/interface list member
add list=USERS interface=v10-lawyers
add list=USERS interface=v20-staff
add list=USERS interface=v40-voice
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v10-lawyers dst-address-list=DC
add chain=forward action=accept in-interface=v10-lawyers dst-address-list=DMS protocol=tcp \
    dst-port=443
add chain=forward action=accept in-interface=v10-lawyers dst-address-list=FS protocol=tcp \
    dst-port=445
add chain=forward action=accept in-interface=v10-lawyers out-interface=v45-print \
    protocol=tcp dst-port=9100
add chain=forward action=accept in-interface=v20-staff dst-address-list=DC
add chain=forward action=accept in-interface=v20-staff dst-address-list=DMS protocol=tcp \
    dst-port=443
add chain=forward action=accept in-interface=v20-staff out-interface=v45-print \
    protocol=tcp dst-port=9100
add chain=forward action=accept src-address=10.20.20.50 dst-address=10.20.60.10 \
    protocol=tcp dst-port=443
add chain=forward action=accept in-interface-list=USERS out-interface-list=WAN
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# no "established" flags, no per-UDP-reply lines: connection tracking handles every reply
# ===== CORE — server, security and management ACLs =====
# CORE — RouterOS has no per-SVI inbound ACL; the same intent lives in the forward
# chain, matched by in-interface=<the VLAN>. Order these before the default-deny.
/ip firewall filter
# V30 SERVERS: established replies, then the short list DC01 may start
add chain=forward in-interface=v30-srv connection-state=established,related action=accept
add chain=forward in-interface=v30-srv src-address=10.20.30.10 dst-address=10.20.0.0/16 \
    protocol=udp dst-port=53,88,389,123,67 action=accept
add chain=forward in-interface=v30-srv src-address=10.20.30.10 dst-address=10.20.99.0/24 \
    protocol=udp dst-port=1812,1813 action=accept comment="RADIUS replies"
add chain=forward in-interface=v30-srv dst-address=10.0.0.0/8 action=drop log=yes \
    comment="no server -> other internal"
add chain=forward in-interface=v30-srv src-address=10.20.30.10 protocol=udp \
    dst-port=53,123 action=accept comment="DC forwarders + NTP out"
add chain=forward in-interface=v30-srv protocol=tcp dst-port=443 action=accept \
    comment="updates + offsite backup"
add chain=forward in-interface=v30-srv action=drop log=yes
# V60 SECURITY: answers reception, NTP only, no internet ever
add chain=forward in-interface=v60-security src-address=10.20.60.10 \
    dst-address=10.20.20.50 connection-state=established action=accept
add chain=forward in-interface=v60-security dst-address=10.20.30.10 protocol=udp \
    dst-port=123 action=accept
add chain=forward in-interface=v60-security action=drop log=yes comment="SECURITY: no \
    internet, ever"
# V99 MGMT: the whole LAN, plus 443 out for firmware
add chain=forward in-interface=v99-mgmt dst-address=10.20.0.0/16 action=accept
add chain=forward in-interface=v99-mgmt protocol=tcp dst-port=443 action=accept
add chain=forward in-interface=v99-mgmt action=drop log=yes
# ===== CORE — apply the ACLs (one per SVI, inbound) =====
# On RouterOS there is no "ip access-group in" to apply per SVI: the rules written
# in the ACL step already match on in-interface=<the VLAN>, so they take effect the
# moment they exist. The only job here is ordering — keep every per-VLAN block above
# the final "chain=forward action=drop" so the default-deny stays last.
/ip firewall filter
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== ACC-1 / ACC-2 — AAA, RADIUS, desk-port template =====
# ACC-1 / ACC-2 — RouterOS dot1x server (CRS3xx) with NPS as RADIUS
/radius add service=dot1x address=10.20.30.10 \
    secret="<radius-shared-secret>" src-address=10.20.99.11
/interface dot1x server
add interface=ether1 auth-types=dot1x,mac-auth reject-vlan-id=666 server-fail-vlan-id=20 \
    comment="desk 1: machine certificate, or MAC for printers"
# … one entry per desk port. NPS returns the VLAN (Tunnel-Pvt-Group-ID) exactly as for Cisco.
# Check the property names on your release; they've changed between RouterOS 7 versions.
/interface bridge port set [find interface=ether1] pvid=666      # dead end until \
    authenticated
# ===== R1-EDGE — LAN side and guest DHCP =====
# R1-EDGE — RB5009: the guest VLAN terminates here (never on the core); transit to CORE
/interface vlan add name=v900 interface=ether3 vlan-id=900
/interface vlan add name=v50-guest interface=ether3 vlan-id=50
/ip address add address=10.20.255.1/29 interface=v900
/ip address add address=10.20.50.1/24 interface=v50-guest
/ip dhcp-server add name=d-guest interface=v50-guest address-pool=p-guest lease-time=4h
# guests get public resolvers, never DC01
/ip dhcp-server network add address=10.20.50.0/24 gateway=10.20.50.1 \
    dns-server=9.9.9.9,1.1.1.1
/queue simple add name=guest target=10.20.50.0/24 max-limit=50M/50M
/ip route add dst-address=10.20.0.0/16 gateway=10.20.255.2
# ===== CORE — uplink to R1, transit SVI, the guest backstop ACL =====
# CORE — the trunk to R1 (guest + transit); a guest-sourced packet is never routed inside
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 \
    frame-types=admit-only-vlan-tagged comment="R1-EDGE"
/interface bridge vlan add bridge=bridge vlan-ids=50,900 tagged=sfp-sfpplus1
/interface vlan add name=v900-transit interface=bridge vlan-id=900
/ip address add address=10.20.255.2/29 interface=v900-transit
/ip firewall filter add chain=forward in-interface=v900-transit src-address=10.20.50.0/24 \
    \
    action=drop log=yes comment="guest backstop"
/ip route add dst-address=0.0.0.0/0 gateway=10.20.255.1
# ===== R1-EDGE — zone-based firewall =====
# R1 (CCR2004) — zones become interface lists, zone pairs become forward rules
/interface list
add name=INSIDE
add name=GUEST
add name=WAN
/interface list member
add list=GUEST interface=v50-guest
# … v10, v20, v30, v40, v45, v60, v99 into INSIDE
/ip firewall filter
add chain=forward action=accept in-interface-list=INSIDE out-interface-list=WAN
add chain=forward action=accept in-interface-list=GUEST out-interface-list=WAN
add chain=forward action=drop in-interface-list=GUEST log=yes log-prefix=GUEST-DROP \
    comment="no GUEST→INSIDE pair = this line"
add chain=input action=accept in-interface-list=WAN protocol=udp dst-port=500,4500 \
    comment="IKE (step 11)"
add chain=input action=accept in-interface-list=WAN protocol=ipsec-esp
# ===== R1-EDGE — put the inside interfaces in their zones =====
# R1-EDGE — RouterOS groups interfaces with lists, not ZBF zones
/interface list add name=INSIDE
/interface list add name=GUEST
/interface list member add list=INSIDE interface=v900
/interface list member add list=GUEST interface=v50-guest
# ===== R1-EDGE — fibre WAN and PAT (route-map form, ready for the second WAN) =====
# R1 (CCR2004) — fibre and NAT
/interface list member add list=WAN interface=ether1
/ip address add address=203.0.113.10/29 interface=ether1 comment="fibre"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# masquerade follows whichever WAN a packet leaves on: no per-interface NAT rules needed
/ip firewall service-port set sip disabled=yes          # SIP ALG off for the hosted PBX
# ===== R1-EDGE — the 5G port and its NAT rule =====
# R1-EDGE — the 5G backup WAN; it floats in at a high distance (= AD 254)
/interface list member add list=WAN interface=ether2
/ip dhcp-client add interface=ether2 default-route-distance=254 use-peer-dns=no \
    comment="5G backup"
/ip firewall nat add chain=srcnat out-interface=ether2 src-address-list=NAT-SRC \
    action=masquerade
# ===== R1-EDGE — IP SLA, tracked default, NAT cleanup =====
# R1 (CCR2004) — recursive failover replaces IP SLA + track
/ip route
add dst-address=1.1.1.1/32 gateway=203.0.113.9 scope=10 comment="probe via \
    fibre"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 \
    comment="main: fibre"
# backup route: used only when the primary is down (failover)
/ip dhcp-client add interface=ether2 default-route-distance=2 use-peer-dns=no \
    comment="5G (bridge mode)"
/interface list member add list=WAN interface=ether2
# netwatch replaces the EEM applet: flush NAT state when the fibre path changes
/tool netwatch add host=1.1.1.1 interval=10s \
down-script="/ip firewall connection remove [find]" up-script="/ip firewall \
        connection remove [find]"
# ===== R1-EDGE — the firm-specific parts of the FlexVPN =====
# R1 (CCR2004) — RouterOS also does IKEv2 with EAP via RADIUS, but most MikroTik
# remote-access builds use WireGuard: simpler, faster, one key per laptop.
/interface wireguard add name=wg-lawyers listen-port=13231
/interface wireguard peers add interface=wg-lawyers public-key="<partner laptop 1 \
    key>" \
    allowed-address=10.20.200.16/32 comment="partner laptop 1"
/ip address add address=10.20.200.1/24 interface=wg-lawyers
/ip firewall filter add chain=input action=accept in-interface-list=WAN protocol=udp \
    dst-port=13231 \
    place-before=0 comment="WireGuard"
# full tunnel: the laptop's config sets AllowedIPs = 0.0.0.0/0
# trade-off: WireGuard has no per-user RADIUS/MFA; MFA moves to the DMS and the EHR-style apps
# ===== R1-EDGE — RADIUS to NPS · CORE — one more reply line =====
# R1-EDGE + the switches — 802.1X to the Windows NPS (DC01) for desk ports and APs
/radius add service=login,wireless address=10.20.30.10 secret=******** \
    src-address=10.20.255.1
# the source address is the transit SVI, so NPS's 1812/1813 replies have a route back
# (the CORE forward rule already permits those replies to 10.20.255.1)
# ===== R1-EDGE — self zone: IKE/ESP in, plus replies to the router's own probes =====
# R1-EDGE — the input chain for the router itself: IKE/ESP in, probe replies, DHCP
/ip firewall filter
add chain=input in-interface-list=WAN protocol=udp dst-port=500,4500 action=accept \
    comment="IKEv2"
add chain=input in-interface-list=WAN protocol=ipsec-esp action=accept
add chain=input in-interface-list=WAN protocol=icmp icmp-options=0:0 action=accept \
    comment="IP SLA probe replies"
add chain=input in-interface-list=WAN protocol=udp dst-port=68 action=accept comment="DHCP \
    on the 5G port"
add chain=input in-interface-list=WAN action=drop log=yes log-prefix=IN-WAN-DROP
# ===== R1-EDGE — hierarchical shaping + LLQ =====
# R1 (CCR2004) — queue tree replaces the LLQ policy
/ip firewall mangle
add chain=postrouting action=mark-packet new-packet-mark=voice out-interface=ether1 \
    dscp=46 passthrough=no
add chain=postrouting action=mark-packet new-packet-mark=signal out-interface=ether1 \
    dscp=24 passthrough=no
add chain=postrouting action=mark-packet new-packet-mark=rest out-interface=ether1 \
    passthrough=no
/queue type add name=fq kind=fq-codel
/queue tree
add name=WAN-OUT parent=ether1 max-limit=95M
add name=voice parent=WAN-OUT packet-mark=voice priority=1 limit-at=10M max-limit=95M
add name=signal parent=WAN-OUT packet-mark=signal priority=2 limit-at=5M max-limit=95M
add name=rest parent=WAN-OUT packet-mark=rest priority=8 max-limit=95M queue=fq
# ===== All devices — the management baseline =====
# All devices — SSH only from MGMT + the VPN admins, remote syslog, nightly export
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip service set ssh address=10.20.99.0/24,10.20.200.0/28
/ip service set winbox address=10.20.99.0/24,10.20.200.0/28
/ip ssh set strong-crypto=yes
/user set admin disabled=yes
/user add name=netadmin group=full password=********
/system ntp client set enabled=yes servers=10.20.30.10
/system logging action add name=mon target=remote remote=10.20.99.20
/system logging add topics=info action=mon
/system logging add topics=firewall action=mon
/system scheduler add name=nightly interval=1d start-time=03:00:00 on-event="/export \
    file=nightly"
# R1 only: no neighbour discovery toward the ISP
/ip neighbor discovery-settings set discover-interface-list=!WAN
