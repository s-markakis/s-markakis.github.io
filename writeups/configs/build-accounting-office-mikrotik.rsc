# Build: The Accounting Office Network — full MikroTik RouterOS config
# s-markakis.github.io/writeups/build-accounting-office.html  ·  illustrative / lab reference, review before use
# secrets shown as ******** — replace them.

# ===== SW1 — VLANs, uplinks, servers and desk ports =====
/system identity set name=SW1
/interface bridge add name=bridge vlan-filtering=no
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 comment="UPLINK to R1" trusted=yes
add bridge=bridge interface=sfp-sfpplus2 comment="DOWNLINK to SW2" trusted=yes
add bridge=bridge interface=ether21 pvid=12 comment="DC-NPS-CA"
add bridge=bridge interface=ether22 pvid=12 comment="FILES-ACCT"
add bridge=bridge interface=ether23 pvid=12 comment="RDS"
/interface bridge vlan
add bridge=bridge vlan-ids=10,12,20,25,30,40,50,60,99 \
    tagged=bridge,sfp-sfpplus1,sfp-sfpplus2
# desks: TEMPORARY untagged STAFF, replaced by RADIUS in step 6
:for i from=1 to=20 do={ /interface bridge port add bridge=bridge \
    interface=("ether" . $i) pvid=20 comment="DESK" }
# DHCP snooping: only 'trusted' ports may answer
/interface bridge set bridge dhcp-snooping=yes
/interface vlan add name=mgmt interface=bridge vlan-id=99
/ip address add address=10.60.99.11/24 interface=mgmt
/interface bridge set bridge vlan-filtering=yes
# ===== R1 — subinterfaces, DHCP relay, guest pool, NAT =====
/system identity set name=R1
/interface vlan
add name=v10-partners interface=sfp-sfpplus1 vlan-id=10
add name=v20-staff interface=sfp-sfpplus1 vlan-id=20
# ...and 12, 25, 30, 40, 50, 60, 99 the same way
/ip address
add address=203.0.113.18/30 interface=ether1
add address=10.60.10.1/24 interface=v10-partners
add address=10.60.20.1/24 interface=v20-staff
/ip dhcp-relay
add name=relay-partners interface=v10-partners dhcp-server=10.60.12.10 \
    local-address=10.60.10.1 disabled=no
/ip pool add name=guest ranges=10.60.50.10-10.60.50.250
/ip dhcp-server add name=guest interface=v50-guest address-pool=guest lease-time=4h
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.17
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
# ===== DC1 — PowerShell · enterprise CA, auto-enrolment template, NPS and its RADIUS clients =====
/radius add service=dot1x,wireless address=10.60.12.10 secret="********" \
    src-address=10.60.99.11 accounting-port=1813 authentication-port=1812 timeout=1s
# NPS sends no CoA, so the incoming listener stays off (see step 11)
/radius incoming set accept=no
# ===== SW1 and SW2 — the OFFICE-NAC policy and the desk ports in open mode =====
# RouterOS has no open mode: a dot1x server on a port enforces from the start.
# Monitor the safe way: failures land in STAFF (as today) while you read the logs.
:for i from=1 to=20 do={ /interface dot1x server add interface=("ether" . $i) \
    auth-types=dot1x,mac-auth reject-vlan-id=20 accounting=yes interim-update=1h }
/system logging add topics=dot1x
# ===== SW1 and SW2 — closed mode, parking VLAN, server-driven reauth =====
# closed: a failure now lands in PARKING (999), which goes nowhere
/interface dot1x server set [find] reject-vlan-id=999
# VLANs arrive from NPS (Tunnel-Private-Group-ID); vlan-filtering must be on
/interface bridge set bridge vlan-filtering=yes
# ===== SW1 and SW2 — LLDP for phones, MAB user-name format for NPS =====
# phones learn voice VLAN 30 from LLDP-MED
/ip neighbor discovery-settings set protocol=lldp lldp-med-net-policy-vlan=30
# MAB user name: the MAC with no separators, lower case, matches the NPS account
/interface dot1x server set [find] mac-auth-mode=mac-as-username \
    radius-mac-format=xxxxxxxxxxxx
# ===== SW1 and SW2 — critical VLAN, voice, and recovery when NPS returns =====
# NPS unreachable: new sessions go to CRIT (60) instead of being rejected
/interface dot1x server set [find] server-fail-vlan-id=60
# ===== EWC — OFFICE (WPA3-Enterprise) and MEETING (WPA3-SAE) =====
/interface wifi security
add name=office authentication-types=wpa3-eap management-protection=required \
    eap-accounting=yes
add name=meeting authentication-types=wpa3-psk passphrase="********" \
    management-protection=required
/interface wifi configuration
add name=office ssid=OFFICE security=office datapath.vlan-id=20
add name=meeting ssid=MEETING security=meeting datapath.vlan-id=50 \
    datapath.client-isolation=yes
# ===== R1 — zones and zone-pairs for the whole matrix =====
/interface list add name=TO-INTERNET
/interface list member
add list=TO-INTERNET interface=v10-partners
add list=TO-INTERNET interface=v20-staff
add list=TO-INTERNET interface=v50-guest
/ip firewall address-list
add list=servers address=10.60.12.0/24
add list=printers address=10.60.40.0/24
/ip firewall filter
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward in-interface=v10-partners dst-address-list=servers action=accept
add chain=forward in-interface=v20-staff dst-address=10.60.12.25 action=drop \
    comment="RDS host is for temps"
add chain=forward in-interface=v20-staff dst-address-list=servers action=accept
add chain=forward in-interface=v25-temp dst-address=10.60.12.25 protocol=tcp \
    dst-port=3389 action=accept
add chain=forward in-interface=v40-print dst-address=10.60.12.20 protocol=tcp \
    dst-port=445 action=accept comment="scan-to-folder"
add chain=forward in-interface=v60-crit dst-address=10.60.12.10 action=accept
add chain=forward in-interface=v60-crit dst-address=10.60.12.20 action=accept
add chain=forward out-interface=ether1 in-interface-list=TO-INTERNET action=accept
add chain=forward action=drop comment="every other zone pair"
# ===== SW1, SW2 and the EWC — interim accounting, session logging, time =====
/system clock set time-zone-name=Europe/Athens
/system ntp client set enabled=yes servers=10.60.12.10
/system logging action add name=dc target=remote remote=10.60.12.10
/system logging add topics=dot1x action=dc
/system logging add topics=info,!debug action=dc
