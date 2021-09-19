#!/bin/bash
# ------------------------------------------------------------------------------------------------
# Usage: This script calculates the % of the routed sats compared
# to the local channel balance for the last 7 days...
#
# It can be executed as a daily cron job to give a nice history
# The results are written to  stdout which can be redirected to a log file by cron.
#
# BOS (Balance of Satoshi) needs to be installed
#
# Add the following in crontab to run regulary. Change path as appropriate
# 55 23 * * * ~/bos_accounting/bos_accounting.sh >> ~/bos_accounting.log 2>&1
# Version: 0.0.7
# Author: Dirk Krienbuehl https://t.me/Deekee62
# Additions : VS https://t.me/BhaagBoseDk : Removing lncli and icreasing compatibilities with other installations.
#
# ------------------------------------------------------------------------------------------------
#

#Replace by actual path to bos if you run in docker

if [ -f $HOME/.npm-global/bin/bos ] 
then
	BOS="$HOME/.npm-global/bin/bos"
else
	BOS=`which bos`
fi

if [ "$BOS" == "" ] || [ ! -f $BOS ]
then
	# Potential Docker Installation
	BOS="docker run --rm --network=host --add-host=umbrel.local:10.21.21.9 -v $HOME/.bos:/home/node/.bos -v $HOME/umbrel/lnd:/home/node/.lnd:ro alexbosworth/balanceofsatoshis"
fi
#BOS=user_specific_path for bos

# Get local channel balance
a_local="$($BOS balance --detailed | grep offchain_balance |  awk -F : '{gsub(/^[ \t]+/, "", $2);print $2}' | sed 's/\.//g' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' | tr -d '\r')"
#
# Get total forwarded amount of sats for the last 7 days
b_routed="$($BOS chart-fees-earned --forwarded --days 7 | grep 'Total:' | awk '{print $8}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' | tr -d '\r')"
#
# Get the total amount of fees earned in the last 7 days
c_earned="$($BOS chart-fees-earned  --days 7 | grep 'Total:' | awk '{print $8}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e s'/^0.//' | tr -d '\r')"
#
# Get the total amount of fees paid in the last 7 days
d_paid="$($BOS chart-fees-paid  --days 7 | grep 'Total:' | awk '{print $9}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' | tr -d '\r')"
#
# Get the total amount of onchain fees paid in the last 7 days
#
e_chainpaid="$($BOS chart-chain-fees  --days 7 | grep 'Total:' | awk '{print $10}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' |  tr -d '\r')"
#
# Calculate the percentage of the forwared sats compared to the local channel balance for the last 7 days
f_pcrouted=`printf "%0.2f" $((100/(10#$a_local/10#$b_routed)))`
#
# Calculate the ppm of the fees earned compared to the local channel balance for the last 7 days
g_ppmearned=$((1000000/$([[ $c_earned == 00000000 ]] && echo $((10#$a_local)) || echo $((10#$a_local/10#$c_earned)))))
#
# Calculate the ppm of the fees paid compared to the local channel balance for the last 7 days
#
h_ppmpaid=$((1000000/$([[ $d_paid == 00000000 ]] && echo $((10#$a_local)) || echo $((10#$a_local/10#$d_paid)))))
#
# Calculate the ppm of the net fees paid compared to the local channel balance for the last 7 days
#
i_ppmnet=$((1000000/(10#$a_local/(10#$c_earned-10#$d_paid-10#$e_chainpaid))))
#
# Calculate the sats of net fees earned
#
k_netearned=`printf "%08d" $((10#$c_earned-10#$d_paid-10#$e_chainpaid))`
#
# Print year, time, local channel balance, forwarded amount, % forwarded, fees earned ppm, fees paid ppm, fees net ppm, amount fees earned, amount fees paid, amount chain fees, amount fees net
#
printf "%(%Y-%m-%d)T    %(%T)T";
printf "    "$a_local"    "$b_routed"    "$f_pcrouted"%%";
printf "   %4d ppm %4d ppm %4d ppm" $g_ppmearned $h_ppmpaid $i_ppmnet; 
printf "   "$c_earned"    -"$d_paid"    -"$e_chainpaid"    "$k_netearned;
printf "\n";
