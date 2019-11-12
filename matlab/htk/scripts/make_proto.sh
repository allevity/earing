#!/bin/sh

# !!! $nbMixtures is no longer used. The code behaves as if nbMixtures=1. !!!
#
# Make prototype in $proto with given number of states, mixtures and vecSize
# Chosen values are hare-coded in this file, and based on examples found in tuto or in other HTK kits.
#
# Example:  sh make_proto.sh $proto 3 1 3"
# <BeginHMM>
#  <NumStates> 3 <StreamInfo> 1 3 <VecSize> 3
#  <DIAGC> <NULLD> <USER>
#  <State> 2 <NumMixes> 1
#   <Stream> 1
#   <Mixture> 1 1.0
#     <Mean> 3
#       0.0 0.0 0.0 
#     <Variance> 3
#       1.0 1.0 1.0 
#   <TransP> 3
#   0.000e+0  1.000e+0  0.000e+0
#   0.000e+0  6.000e-1  4.000e-1
#   0.000e+0  0.000e+0  0.000e+0
# <EndHMM>


EXPECTED_ARGS=5
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` proto nbStates nbMixtures vecsize HTKtype"
  exit $E_BADARGS
fi

proto=$1
nbStates=$2
# nbMixtures=$3 # Actually not used (or expected to be 1!)
vecsize=$4
HTKtype=$5

if [ -z $HTKtype ]; then
	HTKtype="usr"
fi


case "$HTKtype" in
	*usr) 
		typetowrite="USER";;
	USER)
		typetowrite="USER";;
	*mfc)
		typetowrite="MFCC_0_D_A";;
	MFCC_0_D_A)
		typetowrite="MFCC_0_D_A";;
	MFCC_E_D_A_Z)
		typetowrite="MFCC_E_D_A_Z";;
	*) 
		echo " >-< Format ($HTKtype) not recognised" && exit 1;;
esac

printf "" > $proto
echo "<BeginHMM>" >> $proto
echo " <NumStates> $nbStates <StreamInfo> 1 $vecsize <VecSize> $vecsize" >> $proto
echo " <DIAGC> <NULLD> <$typetowrite>" >> $proto
for ((state=2;state<$nbStates;state+=1))
do
	echo " <State> $state <NumMixes> 1" >> $proto
	echo "  <Stream> 1" >> $proto
	echo "  <Mixture> 1 1.0" >> $proto
	echo "    <Mean> $vecsize" >> $proto
	printf "      " >> $proto
	for ((v=1;v<=$vecsize;v+=1))
	do
		printf "0.0 " >> $proto
	done
	echo "" >> $proto
	echo "    <Variance> $vecsize" >> $proto
	printf "      " >> $proto
	for ((v=1;v<=$vecsize;v+=1))
	do
		printf  "1.0 " >> $proto
	done
	echo "" >> $proto
done
echo  "  <TransP> $nbStates" >> $proto

for ((v=1;$v<=$nbStates;v+=1))
do
	for ((w=1;$w<=$nbStates;w+=1))
	do
		if [ $v -eq 1 ]
		then
			if [ $w -eq 2 ]
			then val="1.000e+0"
			else val="0.000e+0"
			fi
		elif [ $v -eq $nbStates ]
		then 
			val="0.000e+0"
		else
			if [ $v -eq $w ]
			then val="6.000e-1"
			elif [ $w -eq $(($v+1)) ]
			then val="4.000e-1"
			else val="0.000e+0"
			fi
		fi
		if [ $w -lt $nbStates ]
		then
			printf "  $val" >> $proto
		else
			printf  "  $val\n" >> $proto
		fi
	done
done
echo "<EndHMM>" >> $proto
exit 0
