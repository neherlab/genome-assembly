# Bacterial genome assembly pipeline written in Nextflow

## Pipeline structure

The computer doing the sequencing should have a python script running that takes care of compressing and uploading to the cluster new `.fast5` files as soon as they get produced by sequencing.

At the same time on the cluster another script should be running that takes care of starting the basecalling as soon as new files become available. This script should use `nextflow` to submit jobs. At the same time as new basecalled `fastq` files become available the next steps of the pipeline should automatically be started.

The automatization should include filtering reads by length, subsampling reads, and running the different assemblers suggested in the trycycle guide.

At this point we should add a script that should recapitulate the data and produce information on the quality of contigs. The user can then decide which contigs should be submitted for the last processing step, which consists in reconciliation with trycycle.

This is the general idea for the directory structure of the project

```
runs
    run_1
        input # input data
            barcode_12
                file_1.fast5.xz
                file_2.fast5.xz
                ...
            barcode_13
                ...
            ...
        basecalled # after basecalling (fastq.gz)
            barcode_12
                ...
            barcode_13
                ...
            ...
        concatenated # filtering out short reads and concatenating
            ...
        subsampled # trycycle subsample
            ...
        assemblies # three different assemblers
            ...
        output # trycicle reconciliation
        
    run_2
       input
       basecalled
       ... 
    ...
```
