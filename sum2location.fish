#!/bin/fish

set -l in_dir './IN/'

alias md5sum ./.bin/md5sum
function sum_command
	read -l tosum
	echo (echo $tosum | md5sum - | tr '[:lower:]' '[:upper:]' | cut -d' ' -f1)
end

echo -e "FILE\tLINE\tMATCH_STRING..."

command ls -1 "$in_dir"*.tsv | while read -l file
	set -l line_num 1
	cat $file | sed -e 's/\r//g' | while read -l line
		set -l checksum (echo $line | sum_command)
		
		if test "$checksum" = "$argv"
			echo -e "$file\t$line_num\t$line"
		end
		set line_num (math $line_num"+1")
	end
end
