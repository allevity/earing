#!/bin/sh

# Create a 'models' file containing a copy of $proto for each monophone found in $monophones0.

EXPECTED_ARGS=4
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` hmm0/models hmm0/proto monophones0 hmm0/sp.ded"
  exit $E_BADARGS
fi

models=$1
proto=$2
monophones0=$3
spded=$4 # Not used anymore, left for simplicity. Probably to delete (because we need to initialise the values by running HERest first)

hmmProtoTemp="${proto}_tmp"
cat $proto > $hmmProtoTemp 	# Prototype: add '| sed "1,4d" ' if we want without first 4 lines

printf  "" > $models
for monop in $(cat $monophones0)
do 
	printf "~h \"$monop\"\n" >> $models  	# Monophone header
	cat $hmmProtoTemp 		 >> $models		# HMM prototype
done
rm $hmmProtoTemp

exit 0