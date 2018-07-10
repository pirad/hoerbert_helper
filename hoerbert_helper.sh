#!/bin/bash

# temporary path where the wav files will be created
tmp_path="/dev/shm/hoerbert.d/"

if [ ! -d "$tmp_path" ] 
then
    mkdir "$tmp_path"
fi

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

function convert_one_source {
    source_path=$(zenity --file-selection --directory --title="Wähle das Quell-Verzeichnis aus.")

    # convert to wav named from 0
    i=0
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for FILE in $(ls -v "$source_path")
    do
	if [[ -f "$source_path/$FILE" && "$source_path/$FILE" =~ ^.*\.(wav|WAV|mp3|MP3)$ ]] 
	then
	   sox --buffer 131072 --multi-threaded --no-glob "$source_path/$FILE" --clobber -r 32000 -b 16 -e signed-integer --no-glob $tmp_path/$i.WAV remix - gain -n -1.5 bass +1 loudness -1 pad 0 0 dither
	   ((i++))
       fi
    done
    IFS=$SAVEIFS


    target_path=$(zenity --file-selection --directory --title="Wähle das Ziel-Verzeichnis aus.")




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
