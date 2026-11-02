#!/system/bin/sh
# UNT431A optimization 2026-11-03:
#  - original script looped forever and was re-executed by init every few seconds
#  - keep the voice service, skip the factory test agents
#  - block LAN access to 6800 (aria2 RPC, 小白文件管理器) and 7777 (go_proxy_video PCDN, 小苹果戏曲)
#  - stop the pure-IPTV services, but NEVER configserver/networkserver (Ethernet/display need them)
#  - self-heal: if the network drops after stopping them, start them again
start xiriservice
for i in eth0 wlan0; do
    iptables -I INPUT -i $i -p tcp --dport 6800 -j DROP 2>/dev/null
    iptables -I INPUT -i $i -p tcp --dport 7777 -j DROP 2>/dev/null
done
sleep 45
stop IptvService
stop iptvd
stop amtprox
sleep 10
if ! ping -c1 -W2 223.5.5.5 >/dev/null 2>&1; then
    start IptvService
    start iptvd
    start amtprox
fi
while true; do sleep 3600; done
