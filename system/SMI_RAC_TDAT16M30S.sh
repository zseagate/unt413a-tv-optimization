#!/system/bin/sh
# UNT431A: replaced the factory eMMC full-disk read loop (16 MB every 30 s + drop_caches)
# with a sleeper, so the init service does not restart-loop.
while true; do sleep 3600; done
