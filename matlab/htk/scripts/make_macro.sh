#!/bin/sh
# Write hmm0/macros, using file vFloors, preceded by variable $vecSize and $par_type (ex: 64 and USER)

EXPECTED_ARGS=4
E_BADARGS=65
vFloors_NOTFOUND=1

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` hmm0/macros hmm0/vFloors vecSize par_type"
  exit $E_BADARGS
fi

macros=$1
vFloors=$2
vecSize=$3
par_type=$4

if [ ! -f $vFloors ]
then 
	echo "ERROR [] vFloors not found by scripts/make_macro.sh"
	exit $vFloors_NOTFOUND
fi

printf "~o <VecSize> $vecSize <$par_type>\n"  >  $macros	# Header
cat $vFloors | sed 's/varFloor1/"varFloor1"/' >> $macros 	# Add quotes 

exit 0