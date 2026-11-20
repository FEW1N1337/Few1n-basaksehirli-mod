#!/bin/sh
/usr/bin/python3 /home/antigravity/ikinci-beyin/beyin.py update
beyin_update_exit=$?
printf "\nKapatmak icin Enter tusuna basin. "
read -r beyin_update_reply || true
exit "$beyin_update_exit"
