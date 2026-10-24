# Build: The Off-Grid Farm — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-farm.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW-SHED — CRS328-24P-4S+ =====
/system identity set name=SW-SHED
# enforcement OFF now, ON at the end (lock-out safety)
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="uplink R1 (10G)"
# … ether2-3: packing PCs
add bridge=bridge interface=ether1 pvid=10 comment="office PC"
add bridge=bridge interface=ether4 pvid=10 comment="scale + label printer"
add bridge=bridge interface=ether5 pvid=40 comment="NVR"
# … ether7-9: yard cams
add bridge=bridge interface=ether6 pvid=40 comment="gate camera"
add bridge=bridge interface=ether10 pvid=99 comment="LoRa gw (trunk)"
add bridge=bridge interface=ether11 pvid=99 comment="shed hAP ax (trunk)"
add bridge=bridge interface=ether12 pvid=99 comment="SXT to greenhouses (trunk)"
/interface bridge vlan
# each VLAN tagged only on ports that must carry it (LoRa trunk never sees the camera VLAN)
add bridge=bridge vlan-ids=10,40 tagged=sfp-sfpplus1
add bridge=bridge vlan-ids=20,50,99 tagged=sfp-sfpplus1,ether11
add bridge=bridge vlan-ids=30,99 tagged=sfp-sfpplus1,ether12
add bridge=bridge vlan-ids=35,99 tagged=sfp-sfpplus1,ether10
add bridge=bridge vlan-ids=99 tagged=bridge
/interface vlan add name=v99-mgmt interface=bridge vlan-id=99
/ip address add address=10.60.99.11/24 interface=v99-mgmt
# just a default gateway (R1) so the switch is reachable
/ip route add gateway=10.60.99.1
# disable unused ports — an open jack is an open door
/interface ethernet disable ether13,ether14,ether15,ether16,ether17,ether18,ether19,ether20,ether21,ether22,ether23,ether24
/interface bridge set bridge vlan-filtering=yes          # now safe to enforce VLANs
# ===== R1 — RB5009 · bridge, trunk, VLAN interfaces, DHCP =====
/system identity set name=R1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged comment="SW-SHED"
/interface bridge vlan
add bridge=bridge vlan-ids=10,20,30,35,40,50,99 tagged=bridge,sfp-sfpplus1
/interface vlan
# one interface per VLAN = router-on-a-stick; each is that VLAN's gateway
add name=v10-ops interface=bridge vlan-id=10
add name=v20-staff interface=bridge vlan-id=20
add name=v30-control interface=bridge vlan-id=30
add name=v35-lns interface=bridge vlan-id=35
add name=v40-cctv interface=bridge vlan-id=40
add name=v50-guest interface=bridge vlan-id=50
add name=v99-mgmt interface=bridge vlan-id=99
/ip address
add address=10.60.10.1/24 interface=v10-ops
add address=10.60.20.1/24 interface=v20-staff
add address=10.60.30.1/24 interface=v30-control
add address=10.60.35.1/24 interface=v35-lns
add address=10.60.40.1/24 interface=v40-cctv
add address=10.60.50.1/24 interface=v50-guest
add address=10.60.99.1/24 interface=v99-mgmt
# staff/guest get short leases; controllers + gateway get reservations
/ip dhcp-server add name=d-staff interface=v20-staff address-pool=p-staff lease-time=4h
/ip dhcp-server add name=d-guest interface=v50-guest address-pool=p-guest lease-time=2h
# … ops, control (reservations), lns (reservation), cctv networks the same way
/ip dns set allow-remote-requests=yes servers=9.9.9.9,149.112.112.112
/system ntp client set enabled=yes servers=time.cloudflare.com
/interface bridge set bridge vlan-filtering=yes
# ===== LoRa GW — wAP LR8 · packet-forwarder to The Things Stack =====
/system identity set name=LORA-GW
# ether1 is the trunk from SW-SHED
/interface vlan add name=v35-lns interface=ether1 vlan-id=35
/interface vlan add name=v99-mgmt interface=ether1 vlan-id=99
/ip address add address=10.60.35.10/24 interface=v35-lns
/ip address add address=10.60.99.12/24 interface=v99-mgmt
/ip route add gateway=10.60.35.1
/ip dns set servers=10.60.35.1
# Semtech UDP packet-forwarder to The Things Stack (EU868)
/iot lora servers add name=tts address=eu1.cloud.thethings.network up-port=1700 down-port=1700
/iot lora set lora0 servers=tts network=public antenna-gain=3
# ===== SXT pair — 5 GHz nv2 bridge carrying the control VLAN =====
/interface wireless set wlan1 mode=ap-bridge band=5ghz-a/n/ac channel-width=20mhz frequency=5500 \
    ssid=farm-ptp wireless-protocol=nv2 nv2-security=enabled nv2-preshared-key="********" distance=1
# radio joins the bridge → the VLAN trunk rides the air
/interface bridge port add bridge=bridge interface=wlan1
# far end: same radio in station-bridge, its ether1 feeds a small switch
# controllers sit on V30 at the far end — untagged on their ports, tagged across the link
# ===== R1 — interface lists, input and forward chains =====
/interface list
add name=WAN
add name=MGMT
/interface list member
add list=MGMT interface=v99-mgmt
/ip firewall address-list
# egress pinned to the vendor by the rules below
add list=VENDOR address=10.60.30.0/24
# input = TO the router; forward = THROUGH it. First match wins; the end drop = default-deny
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface-list=MGMT
add chain=input action=accept in-interface=v35-lns protocol=udp dst-port=53,67
add chain=input action=accept in-interface=v30-control protocol=udp dst-port=53,67
add chain=input action=accept in-interface=v20-staff protocol=udp dst-port=53,67
add chain=input action=accept in-interface=v50-guest protocol=udp dst-port=53,67
# DEFAULT DENY: anything not accepted above is dropped
add chain=input action=drop log=yes log-prefix=IN-DROP
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept in-interface=v10-ops out-interface=v30-control comment="staff run the irrigation dashboards"
add chain=forward action=accept in-interface=v10-ops out-interface=v40-cctv comment="staff view cameras"
add chain=forward action=accept in-interface=v10-ops out-interface-list=WAN
add chain=forward action=accept in-interface=v35-lns out-interface-list=WAN comment="gateway → The Things Stack only"
add chain=forward action=accept in-interface=v30-control out-interface-list=WAN comment="controllers → their vendor cloud (DNS-pinned)"
add chain=forward action=accept in-interface=v20-staff out-interface-list=WAN
add chain=forward action=accept in-interface=v50-guest out-interface-list=WAN
add chain=forward action=accept in-interface=v40-cctv out-interface-list=WAN comment="camera vendor cloud"
add chain=forward action=accept in-interface-list=MGMT
# default-deny: a PLC reaches the internet, never the office/cameras
add chain=forward action=drop log=yes log-prefix=FWD-DROP
# ===== R1 — Starlink in bypass, recursive route kept by the DHCP client =====
/interface list member add list=WAN interface=ether1
/ip route
add dst-address=1.1.1.1/32 gateway=100.64.0.1 scope=10 comment="probe via starlink"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 target-scope=11 check-gateway=ping distance=1 comment="main: starlink"
/ip dhcp-client add interface=ether1 add-default-route=no use-peer-dns=no comment="Starlink (bypass)" script={
  :if ($bound=1) do={ /ip route set [find comment="probe via starlink"] gateway=$"gateway-address" }
}
# optional 4G at distance 2: used only when Starlink is down
/ip dhcp-client add interface=ether2 default-route-distance=2 use-peer-dns=no comment="4G backup"
/interface list member add list=WAN interface=ether2
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
# ===== Solar node — LtAP LR8 LTE · camera + LoRa repeater =====
/system identity set name=NODE-WEST
# let it clock down: every watt is battery
/system routerboard settings set cpu-frequency=auto
/interface lte set lte1 apn-profiles=data
/interface wireguard add name=wg-node listen-port=13232
/interface wireguard peers add interface=wg-node public-key="<hub public key>" endpoint-address=hub.example.net \
    endpoint-port=51820 allowed-address=10.250.0.0/24 persistent-keepalive=25s
/ip address add address=10.250.0.41/24 interface=wg-node
# camera → NVR over the tunnel; LoRa → the same LNS as the shed gateway
/iot lora servers add name=tts address=eu1.cloud.thethings.network up-port=1700 down-port=1700
/iot lora set lora0 servers=tts network=public
# less logging = fewer writes = less power
/system logging action set memory memory-lines=200
# watchdog reboots it on a wedge — nobody's driving out
/system watchdog set watchdog-timer=yes
# ===== R1 — WireGuard to the operator hub, alerts, remote logs =====
/interface wireguard add name=wg-ops listen-port=13231
/interface wireguard peers add interface=wg-ops comment="operator hub" public-key="<hub public key>" \
    endpoint-address=hub.example.net endpoint-port=51820 allowed-address=10.250.0.0/24 persistent-keepalive=25s
/ip address add address=10.250.0.31/24 interface=wg-ops
/interface list member add list=MGMT interface=wg-ops
/system logging action add name=hub target=remote remote=10.250.0.1
/system logging add topics=warning action=hub
# nightly export to the hub over the tunnel (no secrets)
/system scheduler add name=nightly-export start-time=03:00:00 interval=1d on-event={
  /export file=r1-latest ; /tool fetch upload=yes url="sftp://10.250.0.1/backups/r1-latest.rsc" src-path=r1-latest.rsc
}
/tool netwatch add host=1.1.1.1 interval=30s type=simple down-script=":log warning \"Starlink DOWN\"" up-script=":log warning \"Starlink UP\""
