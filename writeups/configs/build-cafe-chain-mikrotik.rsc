# Build: The Café Chain — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-cafe-chain.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== HQ-R1 — CCR2004: the hub, server VLAN, WireGuard head-end =====
# HQ-R1 — CCR2004: the hub. Server VLAN, the NOC, and the WireGuard head-end every shop dials.
/system identity set name=HQ-R1
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port add bridge=bridge interface=ether2 frame-types=admit-only-vlan-tagged comment="HQ switch"
/interface bridge vlan add bridge=bridge vlan-ids=20,30,99 tagged=bridge,ether2
/interface vlan
add name=v20-office interface=bridge vlan-id=20
add name=v30-srv interface=bridge vlan-id=30
add name=v99-noc interface=bridge vlan-id=99
/ip address
add address=10.0.20.1/24 interface=v20-office
add address=10.0.30.1/24 interface=v30-srv
add address=10.0.99.1/24 interface=v99-noc
# the overlay head-end: one WireGuard interface, one peer per shop
/interface wireguard add name=wg-hub listen-port=51820
/ip address add address=10.255.0.1/24 interface=wg-hub
# each shop is a peer: its overlay /32 + its whole 10.<id>.0.0/16 behind it
/interface wireguard peers add interface=wg-hub public-key="<shop-03 pubkey>" \
    allowed-address=10.255.0.4/32,10.3.0.0/16 comment="shop-03 Rethymno"
# HQ routes each shop's block back down its tunnel
/ip route add dst-address=10.3.0.0/16 gateway=10.255.0.4
# ===== SHOP-R1 — hAP ax: VLANs, DHCP, DNS ($SITE per shop) =====
# SHOP-R1 — hAP ax: the shop template. The ONLY thing that changes per shop is $SITE.
:global SITE 3
/system identity set name=("SHOP-" . $SITE)
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port add bridge=bridge interface=ether2 frame-types=admit-only-vlan-tagged comment="SHOP switch"
/interface bridge vlan add bridge=bridge vlan-ids=10,20,30,40,50,99 tagged=bridge,ether2
/interface vlan
add name=v10-pos interface=bridge vlan-id=10
add name=v20-office interface=bridge vlan-id=20
add name=v30-iot interface=bridge vlan-id=30
add name=v40-cctv interface=bridge vlan-id=40
add name=v50-guest interface=bridge vlan-id=50
add name=v99-mgmt interface=bridge vlan-id=99
# the fleet plan: 10.<SITE>.<vlan>.1/24 — identical everywhere but the SITE octet
/ip address add address=("10." . $SITE . ".10.1/24") interface=v10-pos
# … .20 / .30 / .40 / .50 / .99 the same way
/ip dhcp-server add name=d-guest interface=v50-guest address-pool=p-guest lease-time=2h
/ip dhcp-server add name=d-pos interface=v10-pos address-pool=static-only lease-time=1d
# … office + iot pools; the tills and card terminals are reserved by MAC
/ip dns set allow-remote-requests=yes servers=9.9.9.9,1.1.1.1
# ===== SHOP-SW — CRS112: tills, KDS, cameras, AP trunk =====
# SHOP-SW — CRS112-8P-4S: tills, KDS, cameras, an AP trunk, uplink to the router. Identical in every shop.
/system identity set name=("SHOP-" . $SITE . "-SW")
/interface bridge add name=bridge vlan-filtering=yes
/interface bridge port
add bridge=bridge interface=ether1 frame-types=admit-only-vlan-tagged comment="uplink SHOP-R1"
add bridge=bridge interface=ether2 pvid=10 comment="till 1"
add bridge=bridge interface=ether3 pvid=10 comment="till 2 / card terminal"
add bridge=bridge interface=ether4 pvid=30 comment="KDS / menu screen"
add bridge=bridge interface=ether5 pvid=40 comment="camera"
add bridge=bridge interface=ether8 pvid=99 comment="cAP ax (trunk)"
/interface bridge vlan
add bridge=bridge vlan-ids=10,30,40 tagged=ether1
add bridge=bridge vlan-ids=20,50,99 tagged=ether1,ether8
add bridge=bridge vlan-ids=99 tagged=bridge
# ===== SHOP-R1 — one WireGuard tunnel up to HQ (spoke isolation) =====
# SHOP-R1 — one tunnel up to HQ. A shop reaches HQ and central services, never another shop.
/interface wireguard add name=wg-hq listen-port=51820
/interface wireguard peers add interface=wg-hq public-key="<HQ hub pubkey>" \
    endpoint-address=hq.cafe.example endpoint-port=51820 \
    allowed-address=10.0.0.0/16,10.255.0.0/24 persistent-keepalive=25s
/ip address add address=("10.255.0." . ($SITE + 1) . "/24") interface=wg-hq
# central services (POS/ERP/loyalty at HQ) are reached over the tunnel; the default stays local (step 4)
/ip route add dst-address=10.0.0.0/16 gateway=10.255.0.1
# allowed-address scopes the tunnel to HQ's blocks only — there is no route to 10.<other-shop>,
# so a compromised shop cannot reach a sister shop; the hub is the only meeting point
# ===== SHOP-R1 — two WANs, steered by application not just by route =====
# SHOP-R1 — two WANs; the money traffic is steered by APPLICATION, not just a backup route.
/interface list add name=WAN
/interface list member
add list=WAN interface=ether1
add list=WAN interface=lte1
/ip dhcp-client add interface=ether1 use-peer-dns=no comment="WAN1 fibre/VDSL"
/ip dhcp-client add interface=lte1 use-peer-dns=no add-default-route=no comment="WAN2 4G"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# mark what MUST take the reliable path: tills, card terminals, and the HQ tunnel
/ip firewall mangle
add chain=prerouting src-address-list=POS dst-address-list=ACQUIRER action=mark-routing new-routing-mark=money passthrough=no
add chain=prerouting out-interface=wg-hq action=mark-routing new-routing-mark=money passthrough=no
# the money mark prefers WAN1, fails to WAN2; the default (guest + bulk) does the same, separately
/ip route add dst-address=0.0.0.0/0 gateway=ether1 routing-mark=money check-gateway=ping distance=1
/ip route add dst-address=0.0.0.0/0 gateway=lte1 routing-mark=money check-gateway=ping distance=2
/ip route add dst-address=0.0.0.0/0 gateway=ether1 check-gateway=ping distance=1
/ip route add dst-address=0.0.0.0/0 gateway=lte1 check-gateway=ping distance=2
# ===== SHOP-R1 — tills reach the acquirer + HQ only; guests isolated =====
# SHOP-R1 — the tills reach the card acquirer and HQ only; guests get the internet and nothing of ours.
/ip firewall address-list
add list=ACQUIRER address=pay.acquirer.example
add list=POS address=10.3.10.0/24
/ip firewall filter
add chain=forward connection-state=established,related,untracked action=accept
add chain=forward connection-state=invalid action=drop
# tills: the acquirer (card, 443) + the HQ POS/ERP over the tunnel, nothing else
add chain=forward in-interface=v10-pos dst-address-list=ACQUIRER protocol=tcp dst-port=443 action=accept
add chain=forward in-interface=v10-pos out-interface=wg-hq dst-address=10.0.30.0/24 action=accept comment="POS -> HQ ERP/loyalty"
add chain=forward in-interface=v10-pos action=drop log=yes log-prefix=POS-DROP
# cameras record to the HQ NVR over the tunnel; office reaches HQ + internet; guest internet only
add chain=forward in-interface=v40-cctv out-interface=wg-hq dst-address=10.0.30.20 action=accept comment="cameras -> HQ NVR"
add chain=forward in-interface=v50-guest out-interface-list=WAN action=accept comment="guest -> internet only"
add chain=forward in-interface=v20-office action=accept
add chain=forward in-interface=v30-iot out-interface-list=WAN protocol=tcp dst-port=443 action=accept comment="music/KDS cloud"
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== SHOP-R1 — captive-portal guest Wi-Fi; the tills always win =====
# SHOP-R1 — captive-portal guest Wi-Fi, fair per device, and a guarantee the tills always transmit.
/ip hotspot setup
# (guest on v50, a click-through 'trial' profile; per-device pcq limits, as in the coffee-shop build)
# mark the money traffic so the queue can protect it
/ip firewall mangle add chain=forward src-address-list=POS action=mark-packet new-packet-mark=pos passthrough=no
/ip firewall mangle add chain=forward in-interface=v50-guest action=mark-packet new-packet-mark=guest passthrough=no
/queue type add name=guest-pcq kind=pcq pcq-rate=5M pcq-classifier=dst-address
/queue tree
add name=up parent=global max-limit=50M
add name=pos-up parent=up packet-mark=pos limit-at=5M max-limit=50M priority=1
add name=guest-up parent=up packet-mark=guest max-limit=40M queue=guest-pcq priority=8
# priority 1 vs 8: under contention the tills get served first, guests share what is left
# ===== SHOP-R1 — a new shop self-configures from HQ on first boot =====
# Opening a shop: plug the router in, it fetches its own config from HQ. No truck roll with a laptop.
# the factory/default config carries only a bootstrap WAN DHCP + the provisioning key, then runs ztp:
/system script add name=ztp source={
  :global SITE [/system routerboard get serial-number]
  /tool fetch url=("https://provision.cafe.example/sites/" . $SITE . ".rsc") dst-path=site.rsc
  /import file-name=site.rsc
}
/system scheduler add name=firstboot start-time=startup interval=0 on-event=ztp
# HQ renders sites/<serial>.rsc from the ONE template + that site's variables (SITE id, keys, WAN type)
# opening shop #9 is: ship a pre-keyed router, staff plug it in, it joins the overlay in minutes
# ===== HQ — the NOC: scrape every shop, alert on a dark one =====
# HQ — the NOC watches the fleet. A shop that goes dark pages before a barista calls.
# argus stack (VictoriaMetrics + Grafana + vmalert + Alertmanager) scrapes each shop over the overlay
/snmp set enabled=yes contact=noc@cafe.example
/snmp community set [find default=yes] addresses=10.255.0.0/24 comment="poll only over the tunnel"
/system logging action add name=noc target=remote remote=10.0.99.20
/system logging add topics=warning,error action=noc
# a per-site Grafana dashboard + one fleet overview; Alertmanager -> the on-call bot
# (every shop pushes the same metric names, so one dashboard template fits all 8)
# ===== SHOP-R1 — SSH from the NOC only, nightly config to HQ, PCI-clean card path =====
# SHOP-R1 — managed from the NOC over the tunnel; config backed up to HQ nightly; the card path kept clean.
/ip service disable telnet,ftp,www,api,api-ssl
/ip service set ssh address=10.0.99.0/24,10.255.0.0/24
/ip service set winbox address=10.0.99.0/24,10.255.0.0/24
/user set admin disabled=yes
/user add name=netadmin group=full password=********
# nightly export up to HQ over the tunnel; rollback = re-render from the template + re-push
/system scheduler add name=nightly start-time=03:30:00 interval=1d on-event={
  /export file=latest ; /tool fetch upload=yes url="sftp://10.0.99.20/backups/" src-path=latest.rsc user=backup
}
# PCI: the card path (tills -> acquirer) sits on its own VLAN, is logged, and never shares with guest or office
