#!/bin/sh
BACKUP_DIR=~/backup

OS_Version=$(sw_vers -productVersion)
LAST_VERSION=10.13
NEEDS_MODIFICATION=$(echo $OS_Version '>=' $LAST_VERSION | bc -l)
BACKUP_ATTACHMENTS=0

while getopts ":a" opt; do
  case $opt in
    a)
      echo "Running baskup for text + attachments"
      BACKUP_ATTACHMENTS=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

function select_rows () {
  sqlite3 #path to sms backup file "$1"
}

function select_other_rows () {
  sqlite3 #Path to manifest.db "$1"
}


for line in $(select_rows "select distinct guid from chat;" ); do
  contact=$line
  arrIN=(${contact//;/ })
  contactNumber=${arrIN[2]}
  #Make a directory specifically for this folder
  mkdir -p $BACKUP_DIR/$contactNumber/Attachments
  #Perform SQL operations
  if [[ $NEEDS_MODIFICATION == 1 ]]; then
    select_rows "
    select is_from_me,text, datetime((date/1000000000) + strftime('%s', '2001-01-01 00:00:00'), 'unixepoch', 'localtime') as date from message where handle_id=(
    select handle_id from chat_handle_join where chat_id=(
    select ROWID from chat where guid='$line')
    )" | sed 's/1\|/Me: /g;s/0\|/'$contactNumber': /g' > $BACKUP_DIR/$contactNumber/$line.txt
  else
    select_rows "
    select is_from_me,text, datetime(date + strftime('%s', '2001-01-01 00:00:00'), 'unixepoch', 'localtime') as date from message where handle_id=(
    select handle_id from chat_handle_join where chat_id=(
    select ROWID from chat where guid='$line')
    )" | sed 's/1\|/Me: /g;s/0\|/'$contactNumber': /g' > $BACKUP_DIR/$contactNumber/$line.txt
  fi

  if [[ $BACKUP_ATTACHMENTS == 1 ]]; then
    for file in $(select_rows "
    select filename from attachment where rowid in (
    select attachment_id from message_attachment_join where message_id in (
    select rowid from message where cache_has_attachments=1 and handle_id=(
    select handle_id from chat_handle_join where chat_id=(
    select ROWID from chat where guid='$line'))
    ))"); do
      file1=${file:2}

      file2=$(select_other_rows "
      select fileID from files where relativePath = '$file1' and flags = 1")
      file3=${file2:0:2}
      file4=/Users/otisroot/Desktop/ff0147459e199696a5bb73b44d994da986f8aa94/
      file5=/
      file6=$file4$file3$file5$file2
      file7=${file:${#file} - 5}
      cp -p $file6 $BACKUP_DIR/$contactNumber/Attachments
      file8=$file2$file7
      echo $file7
      mv $BACKUP_DIR/$contactNumber/Attachments/$file2 $BACKUP_DIR/$contactNumber/Attachments/$file8
    done
    #cd /Users/otisroot/Library/Application\ Support/MobileSync/Backup/ff0147459e199696a5bb73b44d994da986f8aa94
    #"/Users/otisroot/Desktop/ff0147459e199696a5bb73b44d994da986f8aa94/"
    #| cut -c 2- | awk -v home=$HOME '{print home $0}' | tr '\n' '\0' | xargs -0 -I fname cp fname $BACKUP_DIR/$contactNumber/Attachments

  fi

done
