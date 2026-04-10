#!/bin/fish

# configurables

# end these with '/'
set out_dir './OUT/'
set in_dir './IN/'

set out_file_base $out_dir(date +"%s")
set out_file "$out_file_base.tsv"
set out_file_sorted "$out_file_base-sorted.tsv"
set out_file_csv "$out_file_base-sorted.csv"
set log_file "$out_file_base.log"

# future proof-ables

# should be (header # + 1) because sha key is index 1
set sorter_index 3

# used to check amount of datapoints for a match
set match_number_index 3
# if the amount of occurances of a match number is not equal to this, yell and scream
set scout_count 6
# if the amount of columns in an input file's line is not equal to this, yell and skip
set column_count 10

alias md5sum ./.bin/md5sum
function sum_command
	read -l tosum
	echo (echo $tosum | md5sum - | tr '[:lower:]' '[:upper:]' | cut -d' ' -f1)
end

# start

alias xsv ./.bin/xsv
mkdir -p $out_dir

echo "Getting input files from '$in_dir'..."
if command ls -1 "$in_dir"*.tsv &> /dev/null;
else
	echo " @@@ ERROR: No tsv files matched in '$in_dir'"
	exit 1;
end

echo "Removing dupes (running checksums)..."

set -l dupe_counter 0

command ls -1 "$in_dir"*.tsv | while read -l file
	echo -ne "\nProcessing file '$file'..."
	set -l file_entries (cat $file | grep -v '^$' | wc -l | cut -f1 -d' ')
	set -l entry_number 0

	cat $file | grep -v '^$' | while read -l line
		set entry_number (math "$entry_number+1")
		set -l checksum (echo $line | sum_command)
	  if test "$(echo $line | xsv headers -d'\t' | wc -l)" != "$column_count"
	  	echo -e "\n @@@ WARNING: File '$file' encountered an error on line $entry_number. Skipping. Hash: $checksum" | tee $log_file -a
	  	continue;
	  end;
		
		if grep -E "^$checksum"\t "$out_file" &> /dev/null
			set dupe_counter (math "$dupe_counter+1")
			echo -e "Dupe found! Hash: $checksum" >> $log_file
		else
			echo "$checksum"\t"$line" >> $out_file
		end
		echo -ne "\rProcessing file '$file' [$entry_number/$file_entries]"
	end
end

echo -e "\n$dupe_counter duplicates found and discarded." | tee $log_file -a

echo "Sorting data..."
# xsv select -d'\t' "$sorter_index",1- $out_file | sort -g | xsv select 2- | xsv fmt -t '\t' > $out_file_sorted
xsv sort -d'\t' -s"$sorter_index" -N $out_file | xsv fmt -t '\t' > $out_file_sorted

echo "Checking for missing data..."
xsv select -d'\t' $match_number_index $out_file_sorted | uniq -c | grep '[0-9]+ [0-9]+' -E -o | while read -l matches
	set -l scouted $(echo $matches | cut -d' ' -f1)
  if test "$scouted" != "$scout_count"
		set -l match_num (echo $matches | cut -d' ' -f2)
    echo " @@@ WARNING: Match #$match_num has $scouted data points rather than $scout_count. Hashes: " | tee $log_file -a
		xsv search -n -s"$match_number_index" -d'\t' "^$match_num\$" $out_file | xsv select 1 | awk '{print "   - "$1}' | tee $log_file -a
  end
end

echo "Exporting CSV (just for fun :3)..."
xsv input -d'\t' $out_file_sorted > $out_file_csv
