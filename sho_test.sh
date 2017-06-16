#!/bin/bash
#####################################################################
# This script is to combine all web log files into one big file 
# sorted by IP then time. It accepts two parameters 
# $1 is the input dir - $2 is the output dir 
# Created for showtime networks, copywrited by Mark Naumowicz
#
#     mark@naumowicz.net    (845) 832-4163           06/09/17
#
####################################################################

# --- definitions time ---
input_dir=$1
output_dir=$2
output_file=$output_dir/hwOutputFile.log
dirty_log=$output_dir/dirty_log.txt
# - let's add some conditions

if [[ $# -eq 0 ]] ; then
    echo 'This script accepts two parameters /path/to/input/dir and /path/to/output/dir'
    echo 'Try again...'
    exit 0
fi

if [[ $# -eq 1 ]] ; then
    printf "You have entered $1 - This script needs TWO parameters /path/to/input/dir AND /path/to/output/dir\n"
    echo 'Try again...'
    exit 0
fi

if [[ $# -eq 2 ]] ; then
    printf "You have entered $1 and $2 \nGreat, I have the arguments I need, processing... please wait...\n"
fi

if [ -f $1/hwFile1.log ]; then
    echo "Found the files in $1"
else
    echo "... wait, log files not found in $1!... bailing out..."
    exit 0
fi
# --- Let's roll ---
# - first concat all the files into one dirty log -
# - loop over the files, size doesn't really matter unless you are on 32bit environment
# - cat writes caches to tmp if the files get too big but it still does the job
# - awk would probably choke
# - this really should be done in perl, but for the sake of the homework - mission accomplished :-)

for file in `ls $input_dir/*.log `; do
    printf "processing file $file\n"
    sleep 1
    cat $file >> $dirty_log
done

# --- let's do something with the concatinated data now
# --- the task is to sort it by date AND time
# --- I will convert the timestamp to epoch time, sort it
# --- and convert it back to human redable date the way it was before

while read line; do
     date_field=`echo $line | awk -F"[" '{ print $2 }' | awk ' {print $1 }'`
     epoch=`date -j -f "%d/%b/%Y:%H:%M:%S" $date_field +%s`
     back_from_epoch=`date -j -r $epoch '+%d/%b/%Y:%H:%M:%S'`
     newline=`echo $line | sed -e s*$date_field*$epoch*`
#     printf "$newline\n"
     echo $newline >> dlog.txt #converted to epoch
done <$dirty_log

cat dlog.txt | sort -n -k 1 -k4,4 > dlog_sorted.txt # sorted by ip and date

# --- convert back from epoch to apache time

while read x; do
     ep=`echo $x | awk -F"[" '{ print $2 }' | awk ' {print $1 }'`
     bfe=`date -j -r $ep '+%d/%b/%Y:%H:%M:%S'`
     newx=`echo $x | sed -e s*$ep*$bfe*`
#     printf "$newx\n"
     echo $newx >> sorted_test.txt
done <dlog_sorted.txt

  mv sorted_test.txt $output_file
 
# -  clean up after yourself
rm $dirty_log
rm dlog.txt
rm dlog_sorted.txt


# --- Let's print some hashed progress bar just for the drama of it and some fun :-)

echo -ne '#####                     (33%)\r'
sleep 2
echo -ne '###############           (66%)\r'
sleep 2
echo -ne '##########################(100%)\r'
echo -ne '\n'
