#!/bin/bash

#############
# Settings
#############

QBIT_CATEGORY="rss_anime"
JIMAKU_TOKEN=[REDACTED]

#############
# Help
#############

usage="Usage: $0 <category> <path_to_file> <file_name>"
# in qbittorent run external program after finished
# jimakuOnegai.sh %L %D %N

##################
# Main
##################

if [ -z "$3" ]; then
    kdialog --title "Error: There are required arguments" --passivepopup "$usage"
    exit 1
fi

CATEGORY=$1
PATH_TO_FILE=$2
FILE_NAME=$3

cd $PATH_TO_FILE

# if the category is not the same rss_anime or if it's empty do nothing
if [ "$CATEGORY" != "$QBIT_CATEGORY" ] || [ -z "$CATEGORY" ]; then
    exit 1
fi

# Extract the title by removing brackets and the episode/resolution parts
TITLE=$(echo "$FILE_NAME" | sed -E 's/^\[[^]]*\] //; s/ - [0-9]+.*//; s/\[[^]]*\]//g' | xargs)

# Extract the episode number (assumes it appears before the resolution)
EPISODE=$(echo "$FILE_NAME" | sed -nE 's/.* - ([0-9]+) .*/\1/p')


###########################
# Anilist search
###########################

# Define the AniList API URL
ANILIST_URL='https://graphql.anilist.co'

# Query AniList for the media ID
ANILIST_QUERY='{"query":"query ($search: String) { Media (search: $search, type: ANIME) { id } }","variables":{"search":"'"$TITLE"'"}}'

# Execute the query and get the MEDIA_ID
ANILIST_ID=$(curl -s -X POST -H "Content-Type: application/json" -d "$ANILIST_QUERY" "$ANILIST_URL" | jq '.data.Media.id')

# Check if the media ID was successfully retrieved
if [ "$ANILIST_ID" == "null" ]; then
  kdialog --title "Failed to retrieve media ID from AniList" --passivepopup "Anime title: $TITLE"
  exit 1
fi

##########################
# Jimaku
##########################

# Search url with the anilist_id query
JIMAKU_SEARCH_URL="https://jimaku.cc/api/entries/search?anilist_id=$ANILIST_ID"

# Gets the JIMAKU_ID
JIMAKU_ID=$(curl -s -X GET "$JIMAKU_SEARCH_URL" -H "Authorization: $JIMAKU_TOKEN" | jq '.[0].id')

# Fetch for subtitles with the JIMAKU_ID entry and filters by episode
JIMAKU_FILES_URL="https://jimaku.cc/api/entries/$JIMAKU_ID/files?episode=$EPISODE"

# Gets all options urls
SUBTITLE_FILE_ARRAY=($(curl -s -X GET "$JIMAKU_FILES_URL" -H "Authorization: $JIMAKU_TOKEN" | jq -r '.[].url'))

# Looks for a .srt subtitle in the array (prefered format, no styling)
SRT_FOUND=0
for i in "${SUBTITLE_FILE_ARRAY[@]}";do 
   if [[ "${i: -3}" == "srt" ]];then
       curl -s -L -o "$PATH_TO_FILE/jpn.srt" "$i"
       SRT_FOUND=1
       SUB_EXT="srt"
       break
   fi
done

# if it can't find .srt subtitle
if [ "$SRT_FOUND" -eq 0 ]; then
    curl -s -L -o "$PATH_TO_FILE/jpn.ass" "$i"
    SUB_EXT="ass"
fi

# sync subtitle with video
ffmpeg -hide_banner -i "$FILE_NAME" eng.ass
alass -g eng.ass jpn.$SUB_EXT "${FILE_NAME%.*}".ja.$SUB_EXT
rm eng.ass jpn.$SUB_EXT

kdialog --title "Done" --passivepopup "Subtitle for $TITLE episode $EPISODE was dowloaded and retimed successfully. Enjoy! (＞ｗ＜)b"
