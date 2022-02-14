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
# Version: 0.0.9
# Author: Dirk Krienbuehl https://t.me/Deekee62
# Additions : VS https://t.me/BhaagBoseDk : Removing lncli and increasing compatibilities with other installations.
# Additions : DK https://t.me/Deekee62 : Added command line argument, now the days can be chosen
# ------------------------------------------------------------------------------------------------
#
# Check if arguments have been passed

if [ "$#" -eq  "0" ]
  then
#    printf "No argument passed, using 7 day average as default\n" >&2
    set 7

  elif [[ $# -ne 1 ]]; then
    printf 'Too many/few/wrong arguments, expecting none or one (range 1-7)\n' >&2
    exit

fi

case $1 in
    1|2|3|4|5|6|7)  # Ok
        ;;
    *)
        # The wrong first argument.
        echo 'Expected a number in the range (1-7) as argument' >&2
        exit
esac

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

# Check bos
bos_ver=`$BOS -V`
if [[ "bos_ver" == "" ]]
then
 echo "Error -1 : Unable to run bos. Check $BOS"
 exit -1
fi

# Get local channel balance
a_local="$($BOS balance --detailed | grep offchain_balance |  awk -F : '{gsub(/^[ \t]+/, "", $2);print $2}' | sed 's/\.//g' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' | tr -d '\r')"
#
# Get total forwarded amount of sats for the last X days
b_routed="$($BOS chart-fees-earned --forwarded --days $1 | grep 'Total:' | awk '{print $(NF)}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' -e 's/\.//g' | tr -d '\r')"
#
# Get the total amount of fees earned in the last X days
c_earned="$($BOS chart-fees-earned  --days $1 | grep 'Total:' | awk '{print $(NF)}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e s'/^0.//' | tr -d '\r')"
#
# Get the total amount of fees paid in the last X days
d_paid="$($BOS chart-fees-paid  --days $1 | grep 'Total:' | awk '{print $(NF)}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' | tr -d '\r')"
#
# Get the total amount of onchain fees paid in the last X days
#
e_chainpaid="$($BOS chart-chain-fees  --days $1 | grep 'Total:' | awk '{print $(NF)}' | sed -r -e 's/[[:cntrl:]]\[[0-9]{1,3}m//g' -e 's/\n/ /g' -e 's/^0.//' |  tr -d '\r')"
#
# if e-chainpad is "Total:" only, set default value
if [ "$e_chainpaid" == "Total:" ]
then e_chainpaid="00000000"
fi
#
# Calculate the percentage of the forwarded sats compared to the local channel balance for the last X days
if [ -f /usr/bin/bc ]
then
	f_pcrouted=`echo "scale=2; 100*$b_routed/$a_local" | bc -q`
else
	f_pcrouted=$((100*10#$b_routed/10#$a_local))
fi

#echo "----->"$f_pcrouted"-"$b_routed"-"$a_local

#
# Calculate the ppm of the fees earned compared to the local channel balance for the last X days
g_ppmearned=$((1000000/$([[ $c_earned == 00000000 ]] && echo $((10#$a_local)) || echo $((10#$a_local/10#$c_earned)))))
#
# Calculate the ppm of the fees paid compared to the local channel balance for the last X days
#
h_ppmpaid=$((1000000/$([[ $d_paid == 00000000 ]] && echo $((10#$a_local)) || echo $((10#$a_local/10#$d_paid)))))
#
# Calculate the ppm of the net fees paid compared to the local channel balance for the last X days
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
printf "%#13d%#12d" $a_local $b_routed;
printf "   %#6.2f%%" $f_pcrouted;
printf "   %4d ppm %4d ppm %4d ppm" $g_ppmearned $h_ppmpaid $i_ppmnet;
printf "   "$c_earned"    -"$d_paid"    -"$e_chainpaid"    "$k_netearned;
printf "\n";
