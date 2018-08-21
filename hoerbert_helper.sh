#!/bin/bash

# temporary path where the wav files will be created
# TODO use mktemp
tmp_path=$(mktemp -d)


# functions TODO move to extra file
function move_file {
    # moves file in first argument to directory in second argument and adds third argument to the number in the name
    current_number=${1##*/}
    current_number=${current_number%.WAV}
    new_number=$((current_number + $3))
    mv "$1" "$2/$new_number.WAV"
}

function append_files {
    i=0
    while [ -f "$target_path"/$i.WAV ]
    do
	((i++))
    done
    # todo calculate new file name
    for FILE in "$tmp_path"/*.WAV
    do 
	move_file "$FILE" "$target_path" "$i"
    done
}

function prepend_files {
    number_of_files_to_prepend=0
    while [ -f "$tmp_path"/"$number_of_files_to_prepend".WAV ]
    do
	((number_of_files_to_prepend++))
    done

    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for FILE in $(ls -v -r "$target_path")
    do
	move_file "$target_path"/"$FILE" "$target_path" "$number_of_files_to_prepend"
    done
    IFS=$SAVEIFS

    for FILE in "$tmp_path"/*.WAV
    do 
	move_file "$FILE" "$target_path" 0
    done
}

function my_normalizer {
    file=$1
    tmp=$(sox "$file" -n stats 3>&1 1>&2 2>&3)
    tmp=${tmp#*RMS lev dB}
    rms_lev=${tmp%%.*RMS*}
    diff=$(( -$rms_lev - 17 )) # 17 seems to be normal value on sd card at delivery
    tmpfile=$(mktemp --suffix=.WAV)
    threshold=3
    if [[ $diff -ge $threshold  && $diff -lt 12 ]] 
    then
	sox "$file" "$tmpfile" compand 0.3,0.8 6:-50,-$(( 50 - (2*$diff) )) && \
	    rm "$file" && mv "$tmpfile" "$file"
    fi
}

function count_files_to_normalize {
    i=0
    number_of_files_to_normalize=0
    for FILE in $tmp_path/*.WAV
    do
	tmp=$(sox "$FILE" -n stats 3>&1 1>&2 2>&3)
	tmp=${tmp#*RMS lev dB}
	rms_lev=${tmp%%.*RMS*}
	diff=$(( -$rms_lev - 17 )) # 17 seems to be normal value on sd card at delivery
	threshold=3
	if [[ $diff -ge $threshold  && $diff -lt 12 ]] 
	then
	    ((number_of_files_to_normalize++))
	fi
	((i++))
    done
    echo $number_of_files_to_normalize
}


function convert_all_files {
    # convert to wav named from 0
    i=0
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    file_list=$(ls -v "$source_path")
    number_of_files=$(echo "$file_list" | wc -l)
    for FILE in $file_list
    do
	if [[ -f "$source_path/$FILE" && "$source_path/$FILE" =~ ^.*\.(wav|WAV|mp3|MP3)$ ]] 
	then
	   echo "# Konvertiere $FILE"
	   sox --buffer 131072 --multi-threaded --no-glob "$source_path/$FILE" --clobber -r 32000 -b 16 -e signed-integer --no-glob $tmp_path/$i.WAV remix - gain -n -1.5 bass +1 loudness -1 pad 0 0 dither
	   ((i++))
	   echo $((100 * i / number_of_files))
       fi
    done
    IFS=$SAVEIFS

    number_of_files_to_normalize=$(count_files_to_normalize)
    i=0
    set -x
    if [[ $number_of_files_to_normalize -gt 0 ]] && $(zenity --question --text "$number_of_files_to_normalize Dateien sind leiser als empfohlen. Wollen Sie sie lauter machen (Methode: DRC)?")
    then
	for TMPFILE in $tmp_path/*.WAV
	do 
	    echo "# Normalisiere $TMPFILE"
	    my_normalizer "$TMPFILE"
	    ((i++))
	    echo $((100 * i / number_of_files_to_normalize))
	done
    fi

    set +x
}

function convert_one_source {
    source_path=$(zenity --file-selection --directory --title="Wählen Sie das Quell-Verzeichnis aus.")
    if [ -z $source_path ] 
    then
	exit 1
    fi

    convert_all_files | zenity --progress --title="Konvertiere" --text="Konvertiere" --percentage=0 --auto-close --auto-kill --no-cancel

    target_path=$(zenity --file-selection --directory --title="Wählen Sie das Ziel-Verzeichnis aus.")
    if [ -z $target_path ] 
    then
	exit 1
    fi

    if [ -f "$target_path"/0.WAV ] 
    then
	selection=$(zenity --list --text="Wollen Sie die Dateien hinten anfügen?" --radiolist --column="Auswahl" --column="Beschreibung" "append" "Hinten anfügen" "prepend" "Vorne Anfügen")
	case "$selection" in 
	    Hinten*)
	    append_files
	    ;;
	    Vorne*)
	    prepend_files
	    ;;
	    *)
	    echo "Vorgang abgebrochen"
	    ;;
	esac
    else
	append_files
    fi
}

while :
do
    convert_one_source
    zenity --question --text="Wollen Sie noch ein Verzeichnis übertragen?" || break
done

zenity --notification --text="Danke, dass Sie $0 benutzt haben."
