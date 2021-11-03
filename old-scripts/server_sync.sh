USER='qbiodata'
SERVER='braid.cnsi.ucsb.edu'
DEST='/home/qbiodata/nanopore/runs/20170801_cellulose'
# without trailing slash, this will create a directory at destination
READS='/var/lib/MinKNOW/data/reads'


while true;
do
   rsync -vr --remove-source-files --include "*.fast5" --include "*/" --exclude "*" $READS $USER@$SERVER:$DEST
   sleep 30;
done
