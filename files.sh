# for each line in the file (except header)
#  execute invoke.sh script with first value and append result to the line
# then clean up from double quotes and sort by columns 3 and 4
tail -n +2 a1.txt > a2.txt

sed 's/\"//g' a2.txt > a3.txt

echo "" > a4.txt
while read NAME
do
    echo "$NAME" | sed "s/$1,.*//g" | xargs ./invoke.sh | awk "{print \"$NAME,\"\$1}" >> a4.txt
done < a3.txt

sed 's/\"//g' a4.xt > a5.txt

sort -k4 -k3 -t, a5.txt > a6_final.txt 


#----------------
# awk examples
#----------------
awk 'BEGIN {row=0;v3="";v6="";v9=""} {printf "%d %s\n", FNR, $0} /three/ {v3=$2;next} /six/ {v6=$2;next} /seven/ {v9=$2;next} END { printf "%s %s %s\n", v3, v6 ,v9}'<<-DONE
one two three
four five six
seven eight nine
DONE

1 one two three
2 four five six
3 seven eight nine
two five eight


#----------------
awk '{print $0}'<<-DONE
one two three
four five six
seven eight nine
DONE

one two three
four five six
seven eight nine
$ awk '{print $2}'<<-DONE
one two three
four five six
seven eight nine
DONE

two
five
eight 