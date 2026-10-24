# Build: The Medical Clinic Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-clinic.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-CLINIC — CRS328-24P-4S+ =====
/system identity set name=SW-CLINIC
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=ether24 frame-types=admit-only-vlan-tagged comment="uplink R1"
# … ether2-6
add bridge=bridge interface=ether1 pvid=10 comment="consult room 1 (PC behind phone)"
# … ether8-9
add bridge=bridge interface=ether7 pvid=20 comment="reception 1 (PC behind phone)"
# … ether11-12
add bridge=bridge interface=ether10 pvid=45 comment="printer 1"
# … ether14-18
add bridge=bridge interface=ether13 pvid=60 comment="camera 1"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,45,60 tagged=ether24
add bridge=bridge vlan-ids=40 tagged=ether24,ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9
add bridge=bridge vlan-ids=99 tagged=bridge,ether24
# phones learn their voice VLAN
/ip neighbor discovery-settings set lldp-med-net-policy-vlan=40
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.60.99.11/24 interface=v99-mgmt
/ip route add gateway=10.60.99.1
/interface ethernet disable ether19,ether23
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== SW-MED — CRS326-24G-2S+ =====
/system identity set name=SW-MED
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="uplink R1 (10G)"
add bridge=bridge interface=ether1 pvid=30 learn=no comment="X-ray workstation"
add bridge=bridge interface=ether2 pvid=30 learn=no comment="X-ray detector"
add bridge=bridge interface=ether3 pvid=30 learn=no comment="ultrasound"
add bridge=bridge interface=ether4 pvid=30 learn=no comment="analyzer 1"
add bridge=bridge interface=ether5 pvid=30 learn=no comment="analyzer 2"
add bridge=bridge interface=ether23 pvid=35 comment="PACS + LIS server"
add bridge=bridge interface=ether24 pvid=35 comment="NAS"
# learning is off on device ports: only the device's own MAC may use each one
/interface bridge host
add bridge=bridge interface=ether1 mac-address=00:1E:8F:00:00:11
add bridge=bridge interface=ether2 mac-address=00:1E:8F:00:00:12
# … one static entry per medical device
/interface bridge vlan
add bridge=bridge vlan-ids=30,35 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge,sfp-sfpplus1
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.60.99.12/24 interface=v99-mgmt
/ip route add gateway=10.60.99.1
/interface ethernet disable ether6,ether7,ether8,ether9,ether10,ether11,ether12,ether13,ether14,ether15,\
    ether16,ether17,ether18,ether19,ether20,ether21,ether22,sfp-sfpplus2
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — RB5009 · trunks and VLAN interfaces =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=ether2 frame-types=admit-only-vlan-tagged comment="SW-CLINIC"
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="SW-MED (10G)"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,40,45,50,60 tagged=bridge,ether2
add bridge=bridge vlan-ids=30,35 tagged=bridge,sfp-sfpplus1
add bridge=bridge vlan-ids=99 tagged=bridge,ether2,sfp-sfpplus1
/interface vlan
add name=v10-clinical interface=bridge vlan-id=10
add name=v20-reception interface=bridge vlan-id=20
add name=v30-meddev interface=bridge vlan-id=30
add name=v35-srv interface=bridge vlan-id=35
add name=v40-voice interface=bridge vlan-id=40
add name=v45-print interface=bridge vlan-id=45
add name=v50-patients interface=bridge vlan-id=50
add name=v60-cctv interface=bridge vlan-id=60
add name=v99-mgmt interface=bridge vlan-id=99
/ip address
add address=10.60.10.1/24 interface=v10-clinical
# … .1 on every VLAN interface
/ip dhcp-server
add name=d-clinical interface=v10-clinical address-pool=p-clinical lease-time=1d
add name=d-reception interface=v20-reception address-pool=p-reception lease-time=1d
add name=d-voice interface=v40-voice address-pool=p-voice lease-time=1d
add name=d-print interface=v45-print address-pool=static-only lease-time=1d
add name=d-patients interface=v50-patients address-pool=p-patients lease-time=1h
# MEDDEV, SERVERS and CCTV: static addresses, no DHCP server at all
/ip dns set allow-remote-requests=yes servers=9.9.9.9,149.112.112.112
/system ntp client set enabled=yes servers=time.cloudflare.com
/system ntp server set enabled=yes
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — CAPsMAN for three cAP ax, per-device keys on CLINIC-STAFF =====
/interface wifi security
add name=sec-staff authentication-types=wpa2-psk passphrase="unused-fallback-*****************"
# a datapath ties an SSID to its VLAN — that's the per-SSID isolation
/interface wifi datapath
add name=dp-staff bridge=bridge vlan-id=10
add name=dp-patients bridge=bridge vlan-id=50 client-isolation=yes
/interface wifi configuration
add name=cfg-staff ssid=CLINIC-STAFF security=sec-staff datapath=dp-staff country=Greece
add name=cfg-patients ssid=CLINIC-Patients datapath=dp-patients country=Greece
# each tablet: its own MAC, its own passphrase, on the staff SSID only
/interface wifi access-list
add ssid-regexp="^CLINIC-STAFF\$" mac-address=AA:BB:CC:00:10:01 passphrase="*****************" action=accept comment="tablet 01"
add ssid-regexp="^CLINIC-STAFF\$" mac-address=AA:BB:CC:00:10:02 passphrase="*****************" action=accept comment="tablet 02"
add ssid-regexp="^CLINIC-STAFF\$" action=reject comment="unknown device on the staff SSID"
# one controller pushes this Wi-Fi config to every AP
/interface wifi capsman set enabled=yes interfaces=v99-mgmt
/interface wifi provisioning add action=create-dynamic-enabled master-configuration=cfg-patients \
    slave-configurations=cfg-staff
# patients: 10 Mb/s each, 100/20 in total
/queue type
add name=pcq-pt-down kind=pcq pcq-classifier=dst-address pcq-rate=10M
add name=pcq-pt-up kind=pcq pcq-classifier=src-address pcq-rate=10M
/queue simple add name=patients target=10.60.50.0/24 max-limit=20M/100M queue=pcq-pt-up/pcq-pt-down
# ===== R1 — address lists and forward rules =====
/ip firewall address-list
add list=PACS address=10.60.35.10
add list=LIS address=10.60.35.11
add list=NVR address=10.60.60.10
/interface list
add name=LAN
add name=WAN
add name=MGMT
add name=ONLINE comment="zones that may use the internet"
/interface list member
add list=ONLINE interface=v10-clinical
add list=ONLINE interface=v20-reception
add list=ONLINE interface=v40-voice
add list=ONLINE interface=v50-patients
add list=MGMT interface=v99-mgmt
# … every v* interface into LAN
# input = TO the router; forward = THROUGH it; first match wins; end drop = default-deny
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface-list=MGMT
add chain=input action=accept in-interface-list=LAN protocol=udp dst-port=53,67,123
add chain=input action=accept in-interface-list=LAN protocol=tcp dst-port=53
add chain=input action=drop log=yes log-prefix=IN-DROP
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v30-meddev dst-address-list=PACS protocol=tcp dst-port=104 \
    comment="DICOM store + worklist"
add chain=forward action=accept in-interface=v30-meddev dst-address-list=LIS protocol=tcp dst-port=2575 \
    comment="HL7 lab results"
add chain=forward action=accept in-interface=v10-clinical dst-address-list=PACS protocol=tcp dst-port=443 \
    comment="PACS web viewer"
add chain=forward action=accept in-interface=v10-clinical dst-address-list=LIS protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v20-reception dst-address-list=PACS protocol=tcp dst-port=443 \
    comment="worklist UI"
add chain=forward action=accept in-interface=v20-reception dst-address-list=NVR protocol=tcp dst-port=443
add chain=forward action=accept in-interface=v10-clinical out-interface=v45-print protocol=tcp dst-port=9100
add chain=forward action=accept in-interface=v20-reception out-interface=v45-print protocol=tcp dst-port=9100
add chain=forward action=accept in-interface-list=ONLINE out-interface-list=WAN
add chain=forward action=accept in-interface-list=MGMT
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — fibre, 5G passthrough, recursive failover, NAT =====
/ip address add address=203.0.113.50/29 interface=ether1 comment="fibre"
# backup route: used only when the primary is down (failover)
/ip dhcp-client add interface=ether8 default-route-distance=2 use-peer-dns=no comment="5G passthrough"
/interface list member
add list=WAN interface=ether1
add list=WAN interface=ether8
/ip route
add dst-address=1.1.1.1/32 gateway=203.0.113.49 scope=10 comment="probe via fibre"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 comment="main: fibre"
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# the 5G line is for patient care
/interface list add name=NO5G
/interface list member
add list=NO5G interface=v50-patients
add list=NO5G interface=v35-srv
/ip firewall filter add chain=forward action=reject reject-with=icmp-network-unreachable \
    in-interface-list=NO5G out-interface=ether8 place-before=0 comment="patients and archive uploads never use 5G"
# the archive upload may leave via the fibre
/ip firewall filter add chain=forward action=accept in-interface=v35-srv out-interface=ether1 protocol=tcp dst-port=443 \
    place-before=[find log-prefix=FWD-DROP] comment="PACS/NAS archive to the cloud"
# ===== R1 — mark real-time traffic, queue tree on the fibre =====
/ip firewall mangle
add chain=forward action=mark-packet new-packet-mark=rt-up out-interface=ether1 dscp=46 passthrough=no \
    comment="phones mark EF"
add chain=forward action=mark-packet new-packet-mark=rt-up out-interface=ether1 in-interface=v10-clinical \
    protocol=udp passthrough=no comment="video consultations (WebRTC/UDP)"
add chain=forward action=mark-packet new-packet-mark=bulk-up out-interface=ether1 passthrough=no
add chain=forward action=mark-packet new-packet-mark=rt-down in-interface=ether1 out-interface=v40-voice passthrough=no
add chain=forward action=mark-packet new-packet-mark=rt-down in-interface=ether1 out-interface=v10-clinical \
    protocol=udp passthrough=no
add chain=forward action=mark-packet new-packet-mark=bulk-down in-interface=ether1 passthrough=no
/queue type add name=fq kind=fq-codel
/queue tree
add name=UP parent=ether1 max-limit=95M
add name=up-rt parent=UP packet-mark=rt-up priority=1 limit-at=20M max-limit=95M queue=fq
add name=up-bulk parent=UP packet-mark=bulk-up priority=8 max-limit=95M queue=fq
add name=DOWN parent=global max-limit=475M
add name=down-rt parent=DOWN packet-mark=rt-down priority=1 limit-at=20M max-limit=475M queue=fq
add name=down-bulk parent=DOWN packet-mark=bulk-down priority=8 max-limit=475M queue=fq
# ===== R1 — a disabled rule and two schedules =====
/ip firewall address-list
add list=VENDOR-HUB address=support.vendor.example comment="from the vendor's remote-service guide"
/ip firewall filter add chain=forward action=accept src-address=10.60.30.11 dst-address-list=VENDOR-HUB \
    protocol=tcp dst-port=443 log=yes log-prefix=VENDOR disabled=yes comment=VENDOR-XRAY \
    place-before=[find log-prefix=FWD-DROP]
/system scheduler
add name=vx-open start-date=2026-11-04 start-time=14:00:00 interval=7d on-event={
  /ip firewall filter enable [find comment=VENDOR-XRAY]
  :log warning "vendor window OPEN (X-ray)"
}
add name=vx-close start-date=2026-11-04 start-time=17:00:00 interval=7d on-event={
  /ip firewall filter disable [find comment=VENDOR-XRAY]
  /ip firewall connection remove [find src-address~"^10.60.30.11:"]
  :log warning "vendor window CLOSED (X-ray)"
}
# ===== R1 — WireGuard for the on-call laptop, reaching only the viewer =====
/interface wireguard add name=wg-oncall listen-port=13231
/interface wireguard peers add interface=wg-oncall public-key="<on-call laptop public key>" \
    allowed-address=10.60.200.2/32 comment="on-call laptop 1"
/ip address add address=10.60.200.1/24 interface=wg-oncall
/ip firewall filter
add chain=input action=accept in-interface=ether1 protocol=udp dst-port=13231 \
    place-before=[find log-prefix=IN-DROP] comment="WireGuard on the fibre address"
add chain=forward action=accept in-interface=wg-oncall dst-address-list=PACS protocol=tcp dst-port=443 \
    place-before=[find log-prefix=FWD-DROP] comment="on-call: PACS viewer only"
