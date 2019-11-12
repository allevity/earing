# Script to copy gram on ubuntu server, run HParse on it, and download the wdnet made
# First, requires to launch ubuntuServer from VirtualBox, and check its IP with 
#  /sbin/ifconfig $1 | grep "inet addr" 
IP="000.00.00.0"


EXPECTED_ARGS=2
E_BADARGS=65
E_IPINCORRET=43

if ! ping -t 1 $IP &> /dev/null 
then
	echo " >-< Ping timeout. IP=$IP incorrect, server idle, or not internet connexion. Run" 
	echo " >-<  									                                "
	echo " >-<   /sbin/ifconfig $1 | grep \"inet addr\"    # on ubuntu Server		" 
	echo " >-< login: l......    pwd: d...........					 				"
	echo " >-<  																    "
	echo " >-< and change IP in HParseOnUbuntuServer." && exit $E_IPINCORRET
fi


if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` gram wdnet"
  exit $E_BADARGS	
fi


# File to upload to server (grammar)
gram=$1
# File to download from server (wdnet)
wdnet=$2


#gram="./default/gram_noWORM_WORKING.txt"
#wdnet="./default/wdnet_noWORM_WORKING"

#dataset="timit"
#gram="./default/gram_${dataset}_phones"
#wdnet="./default/wdnet_${dataset}_phones"

#gram="./default/gram_${dataset}_phones_exceptionsOut"
#wdnet="./default/wdnet_${dataset}_phones_exceptionsOut"

echo " --- Copying gram onto Ubuntu server"
scp $gram "l......@${IP}:/home/l...../gram"

echo " --- Running HParse on server through ssh (and waiting for two seconds)..."
ssh "l.....@${IP}" '/home/l...../htk/HTKTools/HParse /home/l....../gram /home/l....../wdnet' 
sleep 2 

echo " --- Getting wdnet from server ..." 
scp "l.....@${IP}:/home/l...../wdnet" $wdnet 

echo " --- Renaming wdnet in case something went wrong and we would download the wrong one..."
ssh "l.....@${IP}" 'mv /home/l...../wdnet /home/l...../wdnetDownloaded'
