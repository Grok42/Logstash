### Hi Justin. John R. Hampton, from your Lake Land College challenge again. 
### If you're open to contribution work from dabblers, would enjoy helping out if desired.
###
###
### Bash scrip we use @ a 1 min tick cron to watch our downed SBC peers for 5 minutes
### This saves us paying PagerDuty $3000/year to get same functionality.
### They call it "Event Intelligence", but we couldn't afford it
### so I spent a couple hours tweaking out this. 
### $10/mo. vs. $3000/year savings for a few hours work. Good deal!
### Also keeps us 1st Responders from getting woken up at 3am for T1s that bounce then right back up.

#!/bin/bash

### cronjob @ 1 min interval
### */1 * * * * /usr/share/logstash/bin/noc-sbc_trap/peer_down.sh

# variables
down_peers=0
noc_alert=0
notify=0
notify_change=0

# base script home
nocPath="/var/log/logstash/noc-sbc_trap"

# SBC SNMPTRAPS go down the 1.SNMPTRAP.conf I submitted. Output all down SBC Peer IPs to one file per peer down.
# Grep directory of those down_files (noc-*.log) then output Grep to down_peers.list
grep -h "DOWN" /$nocPath/peer_down/noc-*.log > /$nocPath/down_peers.list

# Grep down_peers.list & count for total downs.
down_peers=$(grep "DOWN" /$nocPath/down_peers.list | wc -l)

# if any downs continue & output a status line (WATCH) into watched file (filebeat). 
# this is the watched triggered events waiting for cron script to reach 5 minutes.
if [ $down_peers  -gt 0 ];
then
   echo "NOC::CRON-WATCH::SBC_TRAP::PEER_DOWN::$down_peers" >> /$nocPath/noc_alert;

# Else purge junk. Reset stuff. Set state to noc level NONE
else
   rm /$nocPath/down_peers.list;
   rm /$nocPath/csv/down_peers.csv;
   rm /$nocPath/peer_down/noc-*.log;
   echo "NONE::CRON-WATCH::SBC_TRAP::PEER_DOWN::$down_peers" > /$nocPath/noc_alert;
   echo "NONE::CRON-WATCH::SBC_TRAP::PEER_DOWN::$down_peers::$noc_alert::$notify_yes::$notify::$wakeUp" > /$nocPath/notify;
   echo "Y::JOHN" > /$nocPath/notify_enabled;
fi;

# Greps noc_alert log to count NOC alerts 
# (used if IT wants to ignore a down on PD. If a new one comes in it triggers new event).
noc_alert=$(grep "NOC" /$nocPath/noc_alert | wc -l)
# Notify turns off on PD trigger. New downs will have trigger turned back on.
notify_yes=$(grep "Y::" /$nocPath/notify_enabled | wc -l)
# checks to see if any downs remain in the notify file
notify_change=$(grep "CRON-DOWN" /$nocPath/notify | wc -l)
# if notify levels change it adjusts varibles passed to the logline outputs. 
# log watched by filebeat & processed by the 2nd logstash config i may post tomorrow (330am here, sleepy)
# that config does firing off to PD based off these.
if [ $notify_change -gt 0 ];
then
  notify=2;
else
  notify=5;
fi;
# determines if triggers to PD are in WATCH or DOWN (notify)
wakeUp=$(awk -F"::" '{print $2}' /$nocPath/notify_enabled)

# awk to read info from down_peers.list to generate csv to attach to an email alert
# if condition met echos to logs for info & lines needed by 2nd logstash config for PD
if [ $noc_alert -ge $notify ] && [ $notify_yes -gt 0 ];
then
    awk 'BEGIN{FS="::";OFS=","}{print $1,$3,$6,$7,$8}' /$nocPath/down_peers.list > /$nocPath/csv/down_peers.csv
    echo "NOC::CRON-WATCH::SBC_TRAP::PEER_DOWN::$down_peers" > /$nocPath/noc_alert;
    echo "NOC::CRON-DOWN::SBC_TRAP::PEER_DOWN::$down_peers::$noc_alert::$notify_yes::$notify::$wakeUp" > /$nocPath/notify;
# Else cronjob tick message until 5 minutes.
else
    echo "NOC::CRON-WATCH::SBC_TRAP::PEER_DOWN::$down_peers::$noc_alert::$notify_yes::$notify::$wakeUp" > /$nocPath/notify;
fi;

### Will have to double check this may be slightly outdated. Thought I had put a CRON-IDLE message in the line.
