#!/bin/sh

# Make a *.hed file given the number of Gaussian mixtures we want. 'sp' and 'sil' get special treatment, 
# as they play a particular role.
#
# EXAMPLE
# For mix=2, nbStates=16, nbStatesSil=16, DIGITS sp sil in wordlist_sp,
# we obtain a .hed file that looks like that:
# MU 2 {EIGHT.state[2-15].mix}
# MU 2 {FIVE.state[2-15].mix}
# MU 2 {FOUR.state[2-15].mix}
# MU 2 {NINE.state[2-15].mix}
# MU 2 {ONE.state[2-15].mix}
# MU 2 {SEVEN.state[2-15].mix}
# MU 2 {SIX.state[2-15].mix}
# MU 2 {THREE.state[2-15].mix}
# MU 2 {TWO.state[2-15].mix}
# MU 2 {ZERO.state[2-15].mix}
# MU 3 {sil.state[2-15].mix}
# MU 3 {sp.state[2].mix}

EXPECTED_ARGS=5
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh scriptsdir/make_mixupto.sh mixupto{mix}.hed mix wordlist_sp nbStates nbStatesSil"
  exit $E_BADARGS
fi


mixuptomixhed=$1
mix=$2
wordlist_sp=$3
nbStates=$4
nbStatesSil=$5

case "$mix" in 
	2)
		mixup_sp=3
		mixup_sil=3 ;;
	[3-4])
		mixup_sp=6
		mixup_sil=6 ;;
	*) 
		mixup_sp=$mix
		mixup_sil=$mix ;;
esac

# Initialise .hed
: > $mixuptomixhed

# 'sil' and 'sp' get special treatments
for mono in $(cat $wordlist_sp); do
	case $mono in
		"sil")
			let "max_states = $nbStatesSil-1"
			mono_states="2-$max_states"
			mixup="$mixup_sil" ;;
		"sp")
			let mono_states="2"
			mixup="$mixup_sp" ;;
		*)
			let "max_states = $nbStates-1"
			mono_states="2-$max_states"
			mixup=$mix ;; 
	esac

	echo "MU $mixup {$mono.state[$mono_states].mix}" >> $mixuptomixhed
done

exit 0