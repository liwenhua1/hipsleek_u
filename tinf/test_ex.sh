#echo $2
timeout 10s $1 $2.ss --print-min > result/$2.out
#echo $?
OUT=$?
fn=$2.ss
if [ $OUT -eq 124 ];then
   echo "10s Timeout for ${fn}"
else
   echo "Executed ${fn}"
fi