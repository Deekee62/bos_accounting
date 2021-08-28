#!/bin/bash
# ------------------------------------------------------------------------------------------------
# Usage: This script calculates the % of the routed sats compared
# to the local channel balance for the last 7 days...
#
# It can be executed as a daily cron job to give a nice history
# The results are written to /home/umbrel/scripts/routed_percentage.log
#
# BOS (Balance of Satoshi) needs to be installed (docker version)
# bc needs to be installed (sudo apt-get bc)
# jq needs to be installed (sudo apt-get jq)
# A new alias needs to be defined in ~/.bash_aliases
#
# alias boss='docker run --rm --network="host" --add-host=umbrel.local:192.168.1.111 -v \
# HOME/.bos:/home/node/.bos -v $HOME/umbrel/lnd:/home/node/.lnd:ro alexbosworth/balanceofsatoshis'
#
# Version: 0.0.3
# Author: Dirk Krienbuehl https://t.me/Deekee62
# ------------------------------------------------------------------------------------------------
#
# Source the aliases defined
source ~/.bash_aliases
shopt -s expand_aliases
# Get local channel balance
a="$(docker exec lnd lncli channelbalance | /usr/bin/jq -r '.balance')"
#
# Get total forwarded amount of sats for the last 7 days
b="$(boss chart-fees-earned --forwarded --days 7 | /bin/grep 'Total:' | /usr/bin/awk '{print $8}' | /bin/sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' | /bin/sed 's/0.//' | tr -d '\r')"
#
# Get the total amount of fees earned in the last 7 days
c="$(boss chart-fees-earned  --days 7 | /bin/grep 'Total:' | /usr/bin/awk '{print $8}' | /bin/sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' | /bin/sed 's/0.//' | tr -d '\r')"
#
# Get the total amount of fees paid in the last 7 days
d="$(boss chart-fees-paid  --days 7 | /bin/grep 'Total:' | /usr/bin/awk '{print $9}' | /bin/sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' | /bin/sed 's/0.//' | tr -d '\r')"
#
# Calculate the percentage of the forwared sats compared to the local channel balance for the last 7 days
e=$(echo "scale=2; 100/($a/$b)" | /usr/bin/bc -l)
#
# Calculate the ppm of the fees earned compared to the local channel balance for the last 7 days
f=$(echo "scale=0; 1000000/($a/$c)" | bc -l)
#
# Calculate the ppm of the fees paid compared to the local channel balance for the last 7 days
#
g=$(echo "scale=0; 1000000/($a/$d)" | bc -l)
#
# Calculate the ppm of the net fees paid compared to the local channel balance for the last 7 days
#
h=$(echo "scale=0; 1000000/($a/($c-$d))" | bc -l)
#
# Calculate the sats of net fees earned
#
i=$(echo "scale=0; ($c-$d)" | bc -l)
#
# Print year, time, local channel balance, forwarded amount, % forwarded, fees earned ppm, fees paid ppm, fees net ppm, amount fees earned, amount fees paid, amount fees net
#
# printf "%(%Y-%m-%d)T\t%(%T)T\t$a\t$b\t$e %%\t$f ppm\t$g ppm\t$h ppm\t$c\t-$d\t$i\n" >> /home/umbrel/scripts/bos_accounting.log
#
printf "%(%Y-%m-%d)T    %(%T)T    "$a"    "$b"    "$e"%%    "$f"ppm    "$g"ppm    "$h"ppm    "$c"    -"$d"    "$i"\n" >> /home/umbrel/scripts/bos_accounting.log
