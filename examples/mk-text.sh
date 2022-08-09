set -x
set -e
TXT=$1
SEVERED_SIGNED=$2
SIGNED=$3
SEVERED=$4
SUIT=$5
JSON=$6


if python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1])).get("severable") else 1)' $JSON ; then

    echo "Total size of the Envelope without COSE authentication object or Severable Elements: " `stat -f "%z" $SEVERED` >> $TXT
    echo "" >> $TXT
    echo "Envelope:">> $TXT
    echo "" >> $TXT
    echo "~~~" >> $TXT
    xxd -ps $SEVERED >> $TXT
    echo "~~~" >> $TXT

    echo "Total size of the Envelope with COSE authentication object but without Severable Elements: " `stat -f "%z" $SEVERED_SIGNED` >> $TXT
    echo "" >> $TXT
    echo "Envelope:">> $TXT
    echo "" >> $TXT
    echo "~~~" >> $TXT
    xxd -ps $SEVERED_SIGNED >> $TXT
    echo "~~~" >> $TXT

    echo "" >> $TXT
    echo "Total size of Envelope with COSE authentication object and Severable Elements: " `stat -f "%z" $SIGNED`>> $TXT

else
    echo "Total size of Envelope without COSE authentication object: " `stat -f "%z" $SUIT`>> $TXT
    echo "" >> $TXT
    echo "Envelope:">> $TXT
    echo "" >> $TXT
    echo "~~~" >> $TXT
    xxd -ps $SUIT >> $TXT
    echo "~~~" >> $TXT

    echo "" >> $TXT
    echo "Total size of Envelope with COSE authentication object: " `stat -f "%z" $SIGNED`>> $TXT

fi
echo "" >> $TXT
echo "Envelope with COSE authentication object:">> $TXT
echo "" >> $TXT
echo "~~~" >> $TXT
xxd -ps $SIGNED >> $TXT
echo "~~~" >> $TXT
echo "" >> $TXT