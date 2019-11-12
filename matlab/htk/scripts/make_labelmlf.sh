#!/bin/sh

# Write label.mlf. By default, change all labels to uppercase

## Coding comment
# Careful: this line breaks when too many files:
#$ find /Users/p/foldername/*.lab -type f -exec echo '{}' \; > tmp/test.txt
# but not this one:
#$ find /Users/p/foldername -name "*.lab" > tmp/test.txt
#####

EXPECTED_ARGS=3
E_BADARGS=65
LABELSDIR_NOT_FOUND=74

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` labelmlf labelsdir labExtension"
  exit $E_BADARGS	
fi

# label.mlf file to write
labelmlf=$1
# Path where the labels are
labelsdir=$2
# Labels' extension (.lab, .PHN, ...)
labext=$3


echo " --- make_labelmlf.sh: Creating words.mlf... "
echo " --- make_labelmlf.sh: find $labelsdir -name \"*$labext\"..." 


if [ ! -d "$labelsdir" ]; then
	echo "$labelsdir not found. Abort."
	exit $LABELSDIR_NOT_FOUND
fi


# Extracting the word-level labels, within a .mlf
echo "#!MLF!#" > ${labelmlf}_tmpwithpunc
for lab in $(find $labelsdir -name "*$labext"); do
	filename=$(basename $lab $labext)
	echo "\"*${filename}*$labext\""   >> ${labelmlf}_tmpwithpunc 
	# echo "\"*${filename}_*$labext\""   >> ${labelmlf}_tmpwithpunc 
	# Changed \"*/ to \"* to deal with both TRAIN_ or TEST_
	# Changed *$labext to _*$labext to avoid patterns that are not unique (for ex, matching _1_ instead of _16_)

	# cat $lab >> $labelmlf  # if we don't want uppercases
	# Copy and change to uppercase
	# tr '[:lower:]' '[:upper:]' < $lab  >> $labelmlf 
	# If we want to get rid of numbers, and replaces spaces by line breaks, get rid of dots
	# Sentences si1039 and si1071contains --
	# Change sentences beginning with ' by \' (same in dictionary)
	cat "$lab" | \
 		sed "s/[0-9]//g" | \
		sed "s/\.//g" | \
		sed "s/  */ /g" | \
		sed "s/^ //g" | \
		sed "s/ $//g" | \
		tr '[:lower:]' '[:upper:]' | \
		tr " " "\n" >> ${labelmlf}_tmpwithpunc  
	echo "." 		>> ${labelmlf}_tmpwithpunc
done

cat ${labelmlf}_tmpwithpunc | sed 's/?//g' | sed "s/,//g" | sed "s/;//g" | sed 's/!//g' | sed "s/://g" | sed 's/"//g' | sed "/--/d" | sed "s/^'/\\\'/g" | sed 's/#MLF#/#!MLF!#/' > ${labelmlf}
# Put " back for label names"
sed -i "" "s#\*\(.*\)#\"\*\1\"#g" ${labelmlf}

## TESTING 
# Check it's not empty (just with a few things, like #!MLF!#)
if [ `wc -l  $labelmlf  | grep -Eo '[0-9]{1,10}'` -lt 10 ] 
then
	echo " >-< $0: Less than 10 lines put in $labelmlf, there must be a problem to inspect, maybe the labels' format (not . Abort. " && exit 1
fi

exit 0
