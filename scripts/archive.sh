#!/bin/bash

Help(){
        echo
        echo "Script to archive the results to the data folder on the server"
        echo 
        echo "Syntax: bash archive.sh SOURCE DESTINATION"
        echo 
        echo "SOURCE:   Folder in runs/ corresponding to the desired run to archive"
        echo "DEST:     Destination folder in GROUP/data/2022_nanopore_sequencing"
        echo "          NB: this folder must exist."
}

while getopts ":h" option; do
   case $option in
      h) # display Help
         Help
         exit;;
   esac
done

SOURCE=${1%/}
ARCH=${2%/}

for f in $SOURCE/clustering/barcode* ;
do 
        BN=$(basename -- $f)
        DEST=$ARCH/$BN
        mkdir -p $DEST
        cp $f/filtlong_reads.fastq $DEST/filtlong_reads.fastq
        cp -r $f/prokka_$BN $DEST
        for g in $f/cluster_* ;
        do
                GBN=$(basename -- $g)
                DESTG=$DEST/$GBN
                mkdir -p $DESTG
                cp $g/8_medaka.fasta $DESTG
        done
done
