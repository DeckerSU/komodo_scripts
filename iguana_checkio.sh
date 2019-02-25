#!/bin/bash
# (c) fullmoon
myip=$(curl -s4 checkip.amazonaws.com)

establishedconnections=$( ss -a | grep ":7775" | grep "ESTAB" | awk '{print $5 " "  $6}' )

#echo $"$establishedconnections"
outgoing=$( echo $"$establishedconnections" | grep -v "$myip:7775" | awk '{print $2}' | sed 's/:7775//g' | sort  )
#echo $"$outgoing"
ingoing=$( echo $"$establishedconnections" | grep "$myip:7775" | awk '{print $2}' | sed 's/:[0-9]*[0-9]*[0-9]*[0-9]*//g' | sort  )
#echo $"$ingoing"

echo "# outgoing:"
echo $"$outgoing" | wc -l
echo ""
echo "# ingoing:"
echo $"$ingoing" | wc -l
echo ""
echo "IPs not ingoing:"
comm -23 <(echo "$outgoing") <(echo "$ingoing")
echo ""
echo "IPs not outgoing:"
comm -23 <(echo "$ingoing") <(echo "$outgoing")