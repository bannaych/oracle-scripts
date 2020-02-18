#!/bin/bash
# script:   Snapclone.sh - refresh mysql databases using Pure Storge Snapshots
# Author:   Chris Bannayan
# Date:     29/11/2019
# Rev:      0.81
# Platform: Unix,Linux


#
# Define Bold and non-bold screen output
#

BOLD=`tput smso`
NORM=`tput rmso`
SNAPDIR=$PWD/snapdir

# Define the Arrays and Users to connect to
# Sydney Lab

FA1="10.226.224.122"
USER="pureuser"
PGROUP=


# Define the Targeet Volume to refresh
TARGET="mysql-target-data"
# Define htre Primary volume to take snapshots from
SOURCE="mysql-sourc-data"




log_note ()
{
        echo "`date +%d/%m/%y--%H:%M`" $* >> /home/oracle/scripts/pure.log
}

if [ -d $SNAPDIR ]
  then continue
else
  mkdir $SNAPDIR
fi


check_fs ()
{
MOUNT="/data"

if grep -qs $MOUNT /proc/mounts
 then
   echo "$MOUNT is still mounted."
   exit 0
 else
   echo "$MOUNT is not mounted."
fi
}

check_fs1 ()
{
MOUNT=/data

if grep -qs $MOUNT /proc/mounts
 then
   echo "$MOUNT has been mounted."
 else
   echo "$MOUNT is not mounted."
fi
}

RC ()
{
 ERR=$?
   if [ $ERR = 0 ]
       then
       echo "Data Insert successfull"
     else
       echo "Error adding data"
       exit 0
     fi
}

checkmysql ()
{
  systemctl status mysqld | grep inactive
   ERR=$?
     if [ $ERR = 0 ]
       then
       echo "MySQL has been Shutdown "
     else
       echo "MySQL Still not shutdown "
       exit 0
     fi
}


pgroup ()
{

SOURCE="mysql-source-data"

#
# Main loop to create the protection group snap
#
echo ""

      ssh $USER@$FA1 "for i in $SOURCE

             do
               echo "======================================"
               purevol snap  \$i
 done"
echo "Press Enter to continue: "
tput cup 11 25
read ans4
}

# Shutting down Oracle to apply snapshot refresh
#
start=`date` > $SNAPDIR/start-time
tput clear
tput cup 3 15
tput setaf 3
echo "PURE STORAGE MYSQL SNAPCLONE SCRIPT"
tput sgr0

tput cup 5 15 
# Set reverse video mode
tput rev
echo "H O S T   I N F O R M A T I O N"
tput sgr0

tput cup 7 15
echo "Source. MYSQL SOURCE 10.226.225.108"

tput cup 8 15
echo "Target. MYSQL TARGET 10.226.225.109"

tput cup 9 15
echo "FlashArray           10.226.224.122"


tput cup 11 15
tput rev
echo "R E F R E S H    S T E P S"
tput sgr0

tput cup 13 15
echo "Step 1 - Shutdown MySQL Database on Target"
tput cup 15 15
echo "Step 2 - Take protection group snapshot of primary volumes"
tput cup 17 15
echo "Step 3 - Unmount MySQL filesystems on the target"
tput cup 19 15
echo "Step 4 - Refresh the target volumes with the primary volume snapshots"
tput cup 21 15
echo "Step 5 - Remount the MySQL filesystems"
tput cup 23 15
echo "Step 6 - Restart MySQL on the target"


tput cup 25 15
echo "Press Q to quit... "

# Set bold mode
tput bold
tput cup 28 15
read -p "Enter to continue " choice

#tput sgr0
#tput rc
tput clear
tput sgr0

tput cup 3 15
tput setaf 3
echo "VOLUME SNAPSHOT"
tput sgr0
tput cup 5 15
echo "About to Snapshot $SOURCE Y/N: "
tput cup 5 55
read ans3
   case $ans3 in
      y|Y) pgroup;;
      n|N) break;;
  esac





#
# Taking snapshot or source data
#


tput clear
tput cup 3 0
tput setaf 3
tput rev
echo " A B O U T   T O   S H U T D O W N   M Y S Q L "
tput sgr0
tput cup 5 0
echo "Press Enter To shutdown MySQL."
tput cup 5 32
read ans
tput cup 7 0
echo "Shutting down MySQL.."
tput cup 8 0
systemctl stop mysqld
sleep 1
checkmysql
echo
sleep 2
tput cup 15 0
echo "$BOLD Unmounting the /data filesystem $NORM"
umount /data
tput cup 16 0
check_fs
#


#
# ssh to the Pure array and get Volume snap listing
#
ssh $USER@$FA1 "purevol list --snap" > $SNAPDIR/snap.log
ssh $USER@$FA1 "purepgroup list --snap" > $SNAPDIR/snapgroup.log

#
# couple of loops to get Target and Primary volume and output them to a log file
# Get Listing on last 5 snapshots, then pick the snapshot to refresh with.
#


echo "${TARGET}" > $SNAPDIR/snap1.log

awk '/mysql-source/ {print $1,$4,$5}' $SNAPDIR/snap.log|head -5  > $SNAPDIR/snaps
printf "\n"
printf "Select from the following five Latest Snapshots\n "
printf "==========================================="
printf "\n"

PS3="Please enter your choice: "
IFS=$'\n' read -d '' -r -a  options < $SNAPDIR/snaps

select opt in "${options[@]}" quit
do
case  $opt  in
       $opt) echo $opt|awk '{print $1}'|tee $SNAPDIR/cb.log;break;;
       quit) exit 0;;

esac
done
for i in `cat $SNAPDIR/cb.log`; do grep $i $SNAPDIR/snap.log; done|awk '{print $1}'|head -2 >$SNAPDIR/new.log
cat $SNAPDIR/cb.log|awk '{print $1}' > $SNAPDIR/sn.log
paste  $SNAPDIR/new.log $SNAPDIR/snap1.log > $SNAPDIR/cb1.log

#
# Main loop to ssh into array and run the refresh
#

input="$SNAPDIR/cb1.log"

      echo "$BOLD Refreshing from latest $VOLPRIM snapshots `cat $SNAPDIR/cb1.log|awk '{print $1}'` ... $NORM"

      while IFS=" " read -r f1 f2
         do ssh $USER@$FA1 purevol copy --overwrite "$f1" "$f2" </dev/null
      done < "$input"

echo "$BOLD Mounting /data filesystem $NORM"
mount -l /data
sleep 2
check_fs1

echo "$BOLD Starting MySQL.... $NORM"
systemctl start mysqld
end=`date` > $SNAPDIR/end-time
echo
echo
echo "------------------------------------------------------------------------------"
echo
echo "   D A T A B A S E     R E F R E S H    C O M P L E T E                       "
echo "                                                                              "
echo "   Started  :$start                                                           "
echo "   Ended    :$end                                                             "
echo "------------------------------------------------------------------------------"
