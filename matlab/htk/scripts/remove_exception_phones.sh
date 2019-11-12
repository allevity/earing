#!/bin/sh

# Remove the exception phones, following (Lee & Jon 1989)'s' managing of the test phonemes
# Also getting rid of the digits

EXPECTED_ARGS=2
E_BADARGS=65
LABELSDIR_NOT_FOUND=74

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage:   sh `basename $0` typeOfFile textfileWithPhonems"
  exit $E_BADARGS	
fi

# Tpe of file: dict_upper, dict_lower, MLF, list
typeOfFile=$1
# Phone containing phonems file to write
phonefile=$2

# if 'dict' given, check whether it's upper- or lower-case
if [ $typeOfFile == "dict" ]; then
	# Get the first pronunciation. TIMIT's contains '/', handled by a sed
	firstPrononciation=`head -n 1 $phonefile | sed "s/\(.*\) \(.*\)/\2/g" | sed "s#/##g"`
	case ${firstPrononciation:0:1} in
		[[:upper:]]) typeOfFile="dict_upper";;
		[[:lower:]]) typeOfFile="dict_lower";;
		[0-9]      ) echo "Digit: not recognised in remove_exception_phones.sh" && exit 1;;
		* 		   ) echo "First letter of document is neither a letter nor a digit. Should be letter. Abort remove_exception_phones" && exit 1;;
	esac
	#echo " --- Dictionary identified as $typeOfFile"
fi

# dx is also deleted: only appears in the initial .PNH (hence in phones.mlf) but not in dictionary, 
# causing an ERROR 3331 when doing the confusion matrix with HResult
# 
# Careful: 		sed -E "s/ (er|axr)/ er/g" |\  before sed -E "s/ (ah|ax|ax\-h)/ ah/g" |\ otherwise it creates 'ahr'
#  
case $typeOfFile in 
	list|MLF) 
		# Except for 'MLF', we don't excpect  #, so we use this as a space separator
		#
		cat "$phonefile" |\
		tr  "\n" "#" |\
		sed -E "s/(aa|ao)#/aa#/g" |\
		sed -E "s/(er|axr)#/er#/g" |\
		sed -E "s/(ah|ax|ax\-h)#/ah#/g" |\
		sed -E "s/(hh|hv)#/hh#/g" |\
		sed -E "s/(ih|ix)#/ih#/g" |\
		sed -E "s/(l|el)#/l#/g" |\
		sed -E "s/(m|em)#/m#/g"  |\
		sed -E "s/(n|en|nx)#/n#/g" |\
		sed -E "s/(ng|eng)#/ng#/g"  |\
		sed -E "s/(sh|zh)#/sh#/g" |\
		sed -E "s/(uw|ux)#/uw#/g" |\
		sed -E "s/(pcl|tcl|kcl|bcl|dcl|gcl|h#|pau|epi)#/sil#/g" |\
		sed -E "s/q#//g" |\
		sed -E "s/dx#//g" |\
		sed    "s/#\!MLF\!#/MLF/g" |\
		tr     "#" "\n" |\
		sed    "s/MLF/#\!MLF\!#/g" > "${phonefile}_tmp";;
	 "dict_lower") 	
		# For a dictionary, we look for space+phoneme, without the # trick
		# Doing both shouldn't break anything...
		cat "$phonefile" |\
		sed "s/[0-9]//g" |\
		sed -E "s/ (aa|ao)/ aa/g" |\
		sed -E "s/ (er|axr)/ er/g" |\
		sed -E "s/ (ah|ax|ax\-h)/ ah/g" |\
		sed -E "s/ (hh|hv)/ hh/g" |\
		sed -E "s/ (ih|ix)/ ih/g" |\
		sed -E "s/ (l|el)/ l/g" |\
		sed -E "s/ (m|em)/ m/g"  |\
		sed -E "s/ (n|en|nx)/ n/g" |\
		sed -E "s/ (ng|eng)/ ng/g"  |\
		sed -E "s/ (sh|zh)/ sh/g" |\
		sed -E "s/ (uw|ux)/ uw/g" |\
		sed -E "s/ (pcl|tcl|kcl|bcl|dcl|gcl|h#|pau|epi)/ sil/g" |\
		sed -E "s/ q#//g"  > "${phonefile}_tmp";;
	"dict_upper")
		cat "$phonefile" |\
		sed "s/[0-9]//g" |\
		sed -E "s/ (AA|AO)/ AA/g" |\
		sed -E "s/ (ER|AXR)/ ER/g" |\
		sed -E "s/ (AH|AX|AX\-H)/ AH/g" |\
		sed -E "s/ (HH|HV)/ HH/g" |\
		sed -E "s/ (IH|IX)/ IH/g" |\
		sed -E "s/ (L|EL)/ L/g" |\
		sed -E "s/ (M|EM)/ M/g"  |\
		sed -E "s/ (N|EN|NX)/ N/g" |\
		sed -E "s/ (NG|ENG)/ NG/g"  |\
		sed -E "s/ (SH|ZH)/ SH/g" |\
		sed -E "s/ (UW|UX)/ UW/g" |\
		sed -E "s/ (PCL|TCL|KCL|BCL|DCL|GCL|H#|PAU|EPI)/ sil/g" |\
		sed -E "s/ Q#//g"  > "${phonefile}_tmp";;
 	*) echo "Type of file ($typeOfFile) not recognised by remove_exception_phones.sh" && exit 1;;
esac

mv "${phonefile}_tmp" "${phonefile}"

#echo " --- Dealing with exceptions: " 
#exceptions="bcl dcl gcl pcl tck kcl tcl pau epi eng nx hv axr ax-h ux q dx " 
#echo " ---    $exceptions"

exit 0