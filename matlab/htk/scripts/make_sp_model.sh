#!/bin/sh
#
# This function adds a model for 'sp' and a model for 'sil' in the file $model that contains already the trained models.
# Those models are initialised using other models: they are not flat!
# 
# COMMMENT: The lines tr "\n" "\&" and tr "\&" "\n" were used because I didn't find a simpler way to 
# replace something expanded over different lines in bash. This replaces the whole document by one line, 
# the \n being replaced by \&. Then strings are replaced within this line.

EXPECTED_ARGS=4
E_BADARGS=65
E_BADNbSil=2

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "   Usage:   sh `basename $0` prevdir/models dir/sp.ded nbStates nbStatesSil"
  exit $E_BADARGS
fi

msg1=' --- make_sp_model.sh: Adding ~h "sil" model...'
msg2=' --- make_sp_model.sh: Adding ~h "sp" model as T-model with state 3 of sil HMM...'

models=$1
spded=$2
nbStates=$3
nbStatesSil=$4 

# Nb of states for 'sil' model: NOT USED YET
if [ "$nbStatesSil" != "$nbStates" ]; then
	echo "make_sp_model.sh arbitrary nbStatesSil is not implemented yet."
	exit $E_BADNbSil
fi

# Check if there was a model for "sil". Add one if not (if '~h "sil"' not found).
# sil and sp are thus initialised using another HMM, they are not flat!
if ! `cat ${models} | grep '~h "sil"' 1>/dev/null 2>&1`; then
	echo " >-< At this stage there should be a sil model correctly initialised. ERROR []" && exit 1
	echo "$msg1"
	#cat $models | \
	#  	tr "\n" "\&" | \
	#	sed 's/\(.*\)~h "\(.*\)"\(.*\)<ENDHMM>/~h "sil"\3<ENDHMM>/' | \
	#	tr "\&" "\n" >> $models
fi

# Make sp.ded and add it, if necessary (if '~h "sp"' not found)
if [[ -z `cat ${models} | grep "~h" | grep "sp"` ]]; then #  1>/dev/null 2>&1 # without [!-z]
	echo "$msg2"
	cat $models | \
		tr "\n" "\&" | \
		sed 's/\(.*\)~h "sil"\&<BEGINHMM>\(.*\)<ENDHMM>\(.*\)/~h "sp"\&<BEGINHMM>\2<ENDHMM>/' | \
		sed "s/<NUMSTATES>\(.*\)<STATE> 3/<NUMSTATES> 3\&<STATE> 2/" | \
		sed "s/<GCONST>\(.*\)<STATE> 4\(.*\)<TRANSP>/<GCONST>\1 <TRANSP>/" | \
		sed "s/<TRANSP>\(.*\)/<TRANSP> 3 \& 0.0 0.5 0.5\& 0.0 0.5 0.5\& 0.0 0.0 0.0\&<ENDHMM>/" | \
		tr "\&" "\n" > $spded

  	# Former version, changed after meeting Ning on September 22nd 2016
	#cat $models | \
  	#	tr "\n" "\&" | \
  	#	sed 's/\(.*\)~h "\(.*\)"\&<BEGINHMM>\(.*\)<ENDHMM>\(.*\)/~h "sp"\&<BEGINHMM>\3<ENDHMM>/' | \
  	#	sed "s/<NUMSTATES>\(.*\)<STATE> 3/<NUMSTATES> 3\&<STATE> 2/" | \
  	#	sed "s/<TRANSP> $nbStates\(.*\)/<TRANSP> 3 \& 0.0 1.0 0.0\& 0.0 0.9 0.1\& 0.0 0.0 0.0\&<ENDHMM>/" | \
  	# 	sed "s/<GCONST>\(.*\)<STATE> 4\(.*\)/<GCONST>\1<TRANSP> 3 \& 0.0 1.0 0.0\& 0.0 0.9 0.1\& 0.0 0.0 0.0\&<ENDHMM>/" | \
  	#	tr "\&" "\n" > $spded

	# Add to $models
	cat $spded >> $models
fi



exit 0