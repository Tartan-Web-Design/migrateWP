#!/bin/bash 

#################################################################################################
#                                                                                               #
# MigrateWP
#                                                                                               #
# Copies the contents of wp-content from a Local wordpress installation to a remote wordpress   #
# installation and vice versa, using rsync.                                                     #
#                                                                                               #                                                                                              #
# Also carries out a mysqldump of the database, and a search and replace on the site name.      #
#                                                                                               #
# It assumes that the local environment has wp-cli installed and can access it using "wp"       #
#                                                                                               #
#################################################################################################


usage() { 
  echo ""
  echo "##############################################################################"
  echo ""
  echo "Welcome to migrateWP, but you seem to have done something wrong"
  echo ""
  echo Try this:
  echo ""
  echo "Usage: bash migratewp.sh -df [<pull|push|rollback|report>] [Sitename]"
  echo ""
  echo "Please also check migratewp.conf"
  echo ""
  echo "##############################################################################"
  echo ""

  exit 1; }



function errorCheck {
#################################################################################################
#                                                                                               #
# function: errorCheck                                                                          #
#                                                                                               #
#  Catches errors thrown up by wp-cli.                                                          #
#                                                                                               #
#################################################################################################
  status=$?
  if [ $status -eq 1 ]; then
    echo "Error 1: You sure both websites are running?  Exitting"
    exit
  elif [ $status -eq 2 ]; then
    echo "Error 2: You sure both websites are running?  Exitting"
    exit
  elif [ $status -eq 126 ]; then
    echo "Error 3: You sure both websites are running?  Exitting"
    exit
  elif [ $status -eq 128 ]; then
    echo "Error 128: You sure both websites are running?  Exitting"
    exit
  fi
}

function logResult {
#################################################################################################
#                                                                                               #
# function: logResult                                                                           #
#                                                                                               #
#  Logs the result of the run on the remote server                                              #
#                                                                                               #
#################################################################################################

  cd ${runLocation}
  read -p "Add a comment to the log?:  (y/n) " choice
  case $choice in
    y|Y)
      read -p "Comment: " comment
      comment="Comment ${comment}"
      
    ;;

  *)
      echo "OK, no comment... "
    ;;
  esac
  result=$(ssh $sshUser 'bash -s' < ./migratewp.sh writeLog $remotePath $logUserName $1 $remoteURL $localURL $logDate $2 $comment)
  echo $result
}


# migrateWP is recursive, calling itself for some of the remote function calls.  In order to 
# achieve this, it passes through some args to itself as follows:


if [ "$1" == "getPath" ] # Check to find out if the remote directory in arg 2 exists.
  then
    site_url=$2

    if [[ -d  $site_url ]]
      then
        echo true
      else
        echo false
      fi
      exit

  elif [ "$1" == "removeTablePrefixBak" ] # Rolls back changes made to tableprefix 
    then 
      cd $2..
      if test -f wp-tableprefix_bak; then  
          backedupPrefix=$(cat wp-tableprefix_bak)
          current_table_prefix=$(grep table_prefix < wp-config.php | cut -d\' -f2)
          sed -i s/table_prefix\ \=\ \'$current_table_prefix/table_prefix\ \=\ \'$backedupPrefix/ wp-config.php
          rm wp-tableprefix_bak
      fi
      exit
  elif [ "$1" == "createTablePrefixBak" ] # On changing the table prefix, backs up the old one in case of rollback.
    then 
      cd $2..
      table_prefix_remote=$3
      table_prefix_local=$4
      echo $table_prefix_remote > wp-tableprefix_bak
      sed -i s/table_prefix\ \=\ \'$table_prefix_remote/table_prefix\ \=\ \'$table_prefix_local/ wp-config.php
      exit

  elif [ "$1" == "pullDbase" ] # Exports the database on the remote server
    then 
      cd $3..
      wp db export db.sql 
      exit
  elif [ "$1" == "pushDbase" ] # Backs up and replaces the database on the remote server
    then 

      cd $4..
      site_url=$2
      old_url=$3

      wp db export ./db_bak.sql
      wp db import ./db.sql  
      wp search-replace $old_url $site_url
      rm ./db.sql
      exit
  elif [ "$1" == "pushDbaseDryRun" ] # Dry run on the new database, then reverts to previous 
    then 

      cd $4..
      site_url=$2
      old_url=$3

      wp db export ./db_dryrun.sql
      wp db import ./db.sql  
      wp search-replace $old_url $site_url
      wp db import ./db_dryrun.sql
      rm ./db_dryrun.sql
      rm ./db.sql

      exit
  elif [ "$1" == "pushDbaseRollback" ] # Rolls back to previous database
    then 
         
      cd $4..
      wp db import db_bak.sql  

      exit
  elif [ "$1" == "chn" ] # Get the user and group of wp-content on remote server
    then 
      USER=$(stat -c '%U' $2)
      GROUP=$(stat -c '%G' $2)
      if [ -z ${USER} ]; then
        echo *** Error - unable to get owner using chown ***
      else
        echo "$USER:$GROUP"
      fi

      exit
  elif [ "$1" == "checkRemoteSiteRunning" ] # Test if mysql and wp-cli running on remote server
    then 
      cd $2
      cd ..
      result=$(wp db size | grep "There was a database connection issue")
      echo $result
      exit
  elif [ "$1" == "writeLog" ] # Add the log entry of the run just executed
    then 

      if [ "$7" == "Comment" ]; then
        comment="${@:8}"
        rollback=""
      else
        rollback=$7
        comment="${@:9}"
      fi
      cd $2..
      logDate=$(date)
      logEntry="User:${3}  Action:${4} ${rollback}  Remote:${5}  Local:${6}  on  ${logDate}"
      FILE=$2../mwp.log

      if test -f "$FILE"; then
        echo Adding log entry
      else
        echo New log created on $logDate > mwp.log
      fi
      printf '%s ' $logEntry >> mwp.log
      printf '%s\n' ' ' >> mwp.log
      printf '%s ' Comment:  >> mwp.log    
      printf '%s ' $comment >> mwp.log
      printf '%s\n' ' ' >> mwp.log
      result=$(cat mwp.log)
      echo Log Entry Added: "${logEntry}" 

      exit

  else # initial run.  Ie not the rescursive one, the command line.

    # Parse the flags

    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    while getopts "h?fd" opt; do
      case "$opt" in
        h|\?)
          usage
          exit 0
          ;;
        f)  run="full-run"; break
          ;;
        d)  run="dry-run"; break
          ;;
      esac
    done

    if [ -z ${run} ]; then
        site=$2
        action=$1
    else
        site=$3
        action=$2
    fi

    . ./migratewp.conf ## Include the config here so it's not referred to in the recursive calls.

    ## Check if config paths have trailing slash, and add one if they don't
  if [ "${remotePath: -1}" != "/" ]; then
    remotePath="$remotePath"/
  fi

  if [ "${localPath: -1}" != "/" ]; then
    localPath="$localPath"/
  fi

    runLocation=$(pwd)

    # Check that the input args are valid.
    if [ ${action} != "push" ] && [ ${action} != "pull" ] && [ ${action} != "report" ] && [ ${action} != "rollback" ]; then
      usage 
    fi
    

    # If asked, report the log and exit
    if [ ${action} == "report" ]; then
      scp -rq $sshUser:$remotePath../mwp.log ~
      report=~/mwp.log
      if test -f "$report"; then
        cat ~/mwp.log
        rm ~/mwp.log
        exit
      else
        echo "No report available."
        exit
      fi

    fi

fi

function checkEverythingsInPlace {
#################################################################################################
#                                                                                               #
# function: checkEverythingsInPlace                                                             #
#                                                                                               #
#  Checks that all prerequisites for the run are in place.                                      #
#                                                                                               #
#################################################################################################



  # Do we have access to the remote server?
  ssh -q $sshUser exit
  if [ $? == 255 ]; then
    echo Trouble a\' mill - can\'t login using $sshUser
    echo Check migratewp.conf maybe?  Or make sure you have access ssh access. 
    exit
  fi

  cd "$localPath"..

  # Is the local site running and accessable?
  result=$(wp db size 2>&1 | grep "Size")

  if [ -z "$result" ]
  then
      echo "Local site not running - exitting"
      exit
  else
      echo "Local Site running - all good"
  fi

  cd "$runLocation"

  # Is the remote site database running?  TODO, but if it's not, you should already know and have bigger fish to fry...

  # Check to see if mysql is available in this term on local in ENV 
  STR=$(printenv | grep mysql)
  SUB='mysql'
  if [[ "$STR" != *"$SUB"* ]]; then
    export PATH=${PATH}:/usr/local/mysql/bin/ && source ~/.zshrc
  fi

  # Check to see if wp-cli is available in this term on local
  STR=$(wp | grep WordPress)
  SUB='WordPress'
  if [[ "$STR" != *"$SUB"* ]]; then
    echo "You don't have wp-cli installed and/or aliased to wp.  You'll be needing that..."
    echo "Here's where to find the how-to..."
    echo "https://wp-cli.org/"
    echo "But in case that site goes offline, here are the commands:"
    echo "First, download it:"
    echo "   curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
    echo "Then, check it's installed by:"
    echo "   php wp-cli.phar --info"
    echo "If it is, then make it executable:"
    echo "   chmod +x wp-cli.phar"
    echo "Then move it to binaries:"
    echo "   sudo mv wp-cli.phar /usr/local/bin/wp"
    echo "Finally check it again by:"
    echo "   wp --info"
    exit
  fi

  # Check to see if both the local directory and the remote directory actually exist.  
  if [[ -d $localPath ]]
  then
    echo "Local dir found.  All good..."
  else
    echo "Hmmm....  Local dir not found.  You might want to check migratewp.conf.  Exiting"
    exit 
  fi


  remoteExists=$(ssh $sshUser 'bash -s' < ./migratewp.sh getPath $remotePath)

  if [ $remoteExists = "false" ]; 
  then
    echo 'Hmmm.... Remote website not found.  Exiting...'
    exit 1
  else
    echo "Remote dir found.  All good..."
  fi

  # Check to see if the local wp-config.php has a mysqld.sock set for this site

  mysqld_sock=$(grep DB_HOST < "${localPath}"../wp-config.php)
  if [[ $mysqld_sock != *"mysqld.sock"* ]]; then
    echo "<?php phpinfo(); ?>" > "${localPath}"../phpinfo.php
    localPHPInfo=$localPath../phpinfo.php
    if [ -f "$localPHPInfo" ]; then
      sock=$(curl -s http://$localURL/phpinfo.php | grep "Loaded Configuration File" | cut -d/ -f3-9)
      host="localhost:/"$sock"/mysql/mysqld.sock" 
      awk -v srch="localhost" -v repl="$host" '{ sub(srch,repl,$0); print $0 }' "${localPath}"../wp-config.php > ~/temp
      mv ~/temp "${localPath}"../wp-config.php
    else 

    echo "***************************************************************************"
    echo "Error: mysqld_sock not set in wp-config"
    echo "OK, the instructions are in github readme, here's the link:"
    echo "https://github.com/Tartan-Web-Design/migrateWP"
    echo "But essentially, you need to:"
    echo "  1. Go to the Local app,"
    echo "  2. Press the (i) next to PHP Version"
    echo "  3. Find the line under Loaded Configuration File"
    echo "  4. Copy the string between /run/ and /conf/ (should look like random characters"
    echo "  5. Go the wp-config.php, and find the line that looks like:"
    echo "      define( 'DB_HOST', 'localhost' );"
    echo "  6. And replace it with this line:"
    echo "      define( 'DB_HOST', 'localhost:/Users/scott/Library/Application Support/Local/run/XXXXXXX/mysql/mysqld.sock' );"
    echo "  where XXXXXXX is the string from step (4)"
    echo "It just needs done once, at the creation of each new local site"
    echo "***************************************************************************"
    exit
  fi

fi

# Check to see if you're running this script on a Mac
  macOS=$(sw_vers | grep macOS)
  if [[ -z ${macOS} ]]; then
    onAMac=false
  else
    onAMac=true
fi

}



function syncPrefix {
#################################################################################################
#                                                                                               #
# function: syncPrefix                                                                          #
#                                                                                               #
#  Makes sure that the table_prefix in wp-config.php is the same regardless of                  #
#   whether it's a push or a pull.                                                              #
#  Also handles rollback, where the initial push/pull caused the table prefix                   #
#   to be overwritten, but now needs to revert back                                             #
#                                                                                               #
#################################################################################################

  if [ "$1" == "sync" ] ; then
      # Check to see if the table_prefix remote and locally are the same.  
      # If not: 
      #   For pull, overwrite the local with remote prefix.
      #   For push, overwrite the remote with the local prefix.    
      table_prefix_local=$(grep table_prefix < "${localPath}"../wp-config.php)
      table_prefix_remote=$(ssh $sshUser grep table_prefix "${remotePath}"../wp-config.php)
      if [[ "$table_prefix_local" != "$table_prefix_remote" ]]; then
        table_prefix_remote=$(echo $table_prefix_remote | cut -d\' -f2)
        table_prefix_local=$(echo $table_prefix_local | cut -d\' -f2)

        if [[ $action == 'pull' ]]; then
          echo $table_prefix_local > "${localPath}"../wp-tableprefix_bak
          if [ $onAMac == true ]; then
            sed -i '' "s/table_prefix\ \=\ \'$table_prefix_local/table_prefix\ \=\ \'$table_prefix_remote/" "${localPath}"../wp-config.php
          else
            sed -i "s/table_prefix\ \=\ \'$table_prefix_local/table_prefix\ \=\ \'$table_prefix_remote/" "${localPath}"../wp-config.php
          fi

        elif [[ $action == 'push' ]]; then
          result=$(ssh $sshUser 'bash -s' < ./migratewp.sh createTablePrefixBak $remotePath $table_prefix_remote $table_prefix_local)
        else
          exit
        fi
      fi
    elif [[ "$1" == "roll-back" ]]; then
      # On rollback, need to check if the table prefix was changed on the previous run.  If it was, needs to go back.
      if [[ $action == 'pull' ]]; then
        if test -f "${localPath}"../wp-tableprefix_bak; then

            runLocation=$(pwd)
            cd "$localPath"..
            backedupPrefix=$(cat wp-tableprefix_bak)
            current_table_prefix=$(grep table_prefix < wp-config.php | cut -d\' -f2)
          if [ $onAMac == true ]; then
            sed -i '' "s/table_prefix\ \=\ \'$current_table_prefix/table_prefix\ \=\ \'$backedupPrefix/" wp-config.php
          else
            sed -i "s/table_prefix\ \=\ \'$current_table_prefix/table_prefix\ \=\ \'$backedupPrefix/" wp-config.php
          fi

            
            rm wp-tableprefix_bak
            cd "$runLocation"
        fi
      elif [[ $action == 'push' ]]; then
        result=$(ssh $sshUser 'bash -s' < ./migratewp.sh removeTablePrefixBak $remotePath)
      else
        exit
      fi
    fi
  

}

function doRollback {
#################################################################################################
#                                                                                               #
# function: doRollback                                                                          #
#                                                                                               #
# Returns the site selected to the last backup point.                                           #
#                                                                                               #
#################################################################################################

  rollbackLocation=$1
    if [ $rollbackLocation == "remote" ]; then
      echo remote Rollback
        
      ssh $sshUser rsync --owner --group --archive --compress --delete -eh "${remotePath%/}_bak/" "${remotePath}" 
      ssh $sshUser chown -R "${websiteChown}" "${remotePath}"
      action="push"
      syncPrefix "roll-back"
      echo Rollback of Remote Dbase - $remoteURL
      pushDbaseResult=$(ssh $sshUser 'bash -s' < ./migratewp.sh pushDbaseRollback $remoteURL $localURL $remotePath)

      logResult "rollback" $rollbackLocation

    elif [ $rollbackLocation == "local" ]; then
      echo local Rollback
      action="pull"
      rsync --owner --group --archive --compress --delete -eh "${localPath%/}_bak/" "${localPath}" 
      syncPrefix "roll-back"
      cd "$localPath"..
      wp db import db_bak.sql
      logResult "rollback" $rollbackLocation
    fi
  echo Rollback complete
  exit
}

function doSync {

#################################################################################################
#                                                                                               #
# function: doSync                                                                              #
#                                                                                               #
#  Runs Rsync in the direction requested                                                        #
#                                                                                               #
#################################################################################################

  if [ $action == "push" ]; 
    then
      if [[ $run == "full-run" ]]; 
        then
          echo This is a FULL RUN, PUSH...
          echo BACKING UP first...  
          echo Source: "${remotePath}" 
          echo Backup Location: "${remotePath%/}_bak"

          # Take a copy of the remote wp-content folder, for backup
          ssh $sshUser rsync --owner --group --archive --compress --delete -eh "${remotePath}" "${remotePath%/}_bak"

          echo ""
          echo Backup done...
          echo Rsyncing...

          # Overwrite the remote wp-content folder with the local
          rsync --owner --group --archive  --compress --delete -e  "ssh -p 22" --stats "${localPath}" "$sshUser:${remotePath}"
          ssh $sshUser chown -R "${websiteChown}" "${remotePath}"

      elif [[ $run == "dry-run" ]]; 
        then

          echo This is a DRY RUN, PUSH...
          # Use rsyncs dry-run feature to report on what would happen if you pushed
          rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh  -p 22" --stats "${localPath}" "$sshUser:${remotePath}"

      fi

    elif [ $action == "pull" ]; 
    then
      if [[ $run == "full-run" ]]; 
        then

          echo FULL RUN, PULL...
          echo BACKING UP...  Source: "${localPath}" Backup Location: "${localPath%/}_bak"

          # Take a copy of the local wp-content folder, for backup
          rsync --owner --group --archive --compress --delete -eh "${localPath}" "${localPath%/}_bak"

          echo PULLING...

          # Overwrite the local wp-content folder with the remote
          rsync --owner --group --archive  --compress --delete -e  "ssh -p 22" --stats "$sshUser:${remotePath}" "${localPath}"

      elif [[ $run == "dry-run" ]]; then

        echo ""
        echo This is a DRY RUN, PULL...
          # Use rsyncs dry-run feature to report on what would happen if you pulled
        rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh -p 22" --stats "$sshUser:${remotePath}" "${localPath}"

     fi
    elif [ $action == "rollback" ]; 
    then
      timestampRemote=$(ssh $sshUser date -r  "${remotePath}"../db_bak.sql  "+%Y-%m-%d\ %H:%M\ %Z" 2>/dev/null)  
      timestampLocal=$(date -r "${localPath}"../db_bak.sql  "+%Y-%m-%d %H:%M %Z" 2>/dev/null)
      if [ -n "${timestampRemote}" ] && [ -n "${timestampLocal}" ]; then
        echo "Available rollback on Remote: $remoteURL" created at $timestampRemote
        echo "Available rollback on Local: $localURL" created at $timestampLocal
        read -p "Rollback Remote (r) or Local (l)? " choice
        case $choice in
          r|R|remote|Remote)
            doRollback remote 
          ;;
          l|L|local|local)
            doRollback local
          ;;
          *)
            echo "No choice made, exitting... "
            exit
          ;;
        esac
      elif [ -n "${timestampRemote}" ]; then
        echo 'No rollback available on Local'
        echo "Available rollback on $remoteURL" created at $timestampRemote
        read -p "Rollback Remote? (y/n) " choice
        case $choice in
          y|Y|yes|Yes)
            doRollback remote 
          ;;
          *)
            echo "OK, no rollback. Exitting... "
            exit
          ;;
        esac
      elif [ -n "${timestampLocal}" ]; then
        echo 'No rollback available on Remote'
        echo "Available rollback on $localURL" created at $timestampLocal
        read -p "Rollback Local? (y/n) " choice
        case $choice in
          y|Y|yes|Yes)
            doRollback local 
          ;;
          *)
            echo "OK, no rollback. Exitting... "
            exit
          ;;
        esac
      else
        echo nothing available
        exit
      fi


    fi


}

function doDbaseSync {

#################################################################################################
#                                                                                               #
# function: doDbaseSync                                                                        #
#                                                                                               #
#                                                                                               #
#################################################################################################



if [[ $action == 'pull' ]]; 
  then

      syncPrefix "sync"   
          echo Pulling remote database... 
           pullDbaseResult=$(ssh $sshUser 'bash -s' < ./migratewp.sh pullDbase $remoteURL $remotePath)
           echo $pullDbaseResult
        echo Copying dbase from remote... 
        scp -r $sshUser:$remotePath../db.sql "${localPath}"..
        echo Removing dbase from remote...
        ssh $sshUser rm $remotePath..//db.sql
          cd "$localPath"..
      if [[ $run == "dry-run" ]]; 
        then
          syncPrefix "sync" 
        echo Exporting local database...
        wp db export db_dryrun.sql
        echo importing remote database...
        wp db import db.sql 
        echo Search and replace old - $remoteURL - with new $localURL
        wp search-replace $remoteURL $localURL --dry-run
        echo re-importing local database...
        wp db import db_dryrun.sql
        rm db_dryrun.sql
        rm db.sql
        syncPrefix "roll-back" 
        exit
      else # Must be full-run 
      syncPrefix "sync" 
        echo Exporting dbase backup
        wp db export db_bak.sql
        errorCheck
        wp db import db.sql 
        errorCheck
        echo Search and replace old - $remoteURL - with new $localURL
        wp search-replace $remoteURL $localURL 
        errorCheck
        rm db.sql
    fi

  elif [[ $action == 'push' ]]; 
    then
      if [[ $run == "full-run" ]]; 
        then
      syncPrefix "sync"
          echo Syncing Dbase 
          runLocation=$(pwd)
          cd "$localPath"..
          wp db export db.sql
          errorCheck

          scp -r db.sql $sshUser:"${remotePath}"../db.sql 
          rm db.sql
          cd $runLocation
          pushDbaseResult=$(ssh $sshUser 'bash -s' < ./migratewp.sh pushDbase $remoteURL $localURL $remotePath)

          successMessage='Success: Imported'
          replaceSuccessMessage='replacements'

          if [[ "$pushDbaseResult" == *"$successMessage"* ]] ; 
            then
              echo $successMessage database
          else
              echo Failed to import
              exit
          fi
    
          if [[ "$pushDbaseResult" == *"$replaceSuccessMessage"* ]] ; 
            then

              printf '%s\n' "${pushDbaseResult}"
            else
              echo Failed to search and replace
              exit
          fi
      elif [[ $run == "dry-run" ]]; 
        then
      syncPrefix "sync"
          echo Dry Run Sync of Remote Dbase 

          runLocation=$(pwd)
          cd "$localPath"..
          wp db export db.sql
          errorCheck
          scp -r db.sql $sshUser:"${remotePath}"../db.sql 
          rm db.sql
          cd $runLocation
          echo ABOUT TO DRY-RUN 

          pushDbaseResult=$(ssh $sshUser 'bash -s' < ./migratewp.sh pushDbaseDryRun $remoteURL $localURL $remotePath)

          successMessage='Success: Imported'
          replaceSuccessMessage='replacements'
          if [[ "$pushDbaseResult" == *"$successMessage"* ]] ; 
            then
              echo $successMessage database
          else
              echo Failed to import
              exit
          fi
          if [[ "$pushDbaseResult" == *"$replaceSuccessMessage"* ]] ; 
            then

              printf '%s\n' "${pushDbaseResult}"
          else
              echo Failed to search and replace
              exit
          fi
          syncPrefix "roll-back"
          exit
      fi

  else
      exit 1
  fi



}




# Tell the user what you're about to do
if [[ $action == 'pull' ]]; then
  echo "Pulling $remotePath to $localPath"
elif [[ $action == 'push' ]]; then
  echo "About to push:"
  echo "   $localPath to"
  echo "   $remotePath"
elif [[ $action == 'rollback' ]]; then
  echo "Roll Back Selected"
fi


# Get the user and group owners of the remotePath dir, to make sure we set them back once we transfer
websiteChown=$(ssh $sshUser 'bash -s' < ./migratewp.sh chn $remotePath)
echo User:Group - $websiteChown

checkEverythingsInPlace
if [ -z ${run} ] && [ ${action} != "rollback" ]; then
  
  run="full-run"

fi
doSync
doDbaseSync
logResult $action

