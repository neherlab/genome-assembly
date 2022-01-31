USER='d_nanopore'
SERVER='login.scicore.unibas.ch'
DEST='/home/qbiodata/nanopore/runs/20170801_cellulose'
# without trailing slash, this will create a directory at destination
READS='/var/lib/MinKNOW/data/reads'


while true;
do
   rsync -varu --include "*.fast5" --include "*/" --exclude "*" $READS $USER@$SERVER:$DEST
   sleep 300;
done

# rsync relevant options:
# -a : transfer in archive mode
# -v : verbose
# -r : recursive
# -u : update. Skips files that are newer on the receiver.
# -n : performs a dry run
# --ignore-existing : ignores files that already exist on the receiver
# --remove-source-files : sender removes synchronized files