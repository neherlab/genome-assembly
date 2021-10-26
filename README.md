# Bacterial genome assembly pipeline written in Nextflow

## Pipeline structure

The computer doing the sequencing should have a python script running that takes care of compressing and uploading to the cluster new `.fast5` files as soon as they get produced by sequencing.

At the same time on the cluster another script should be running that takes care of starting the basecalling as soon as new files become available. This script should use `nextflow` to submit jobs and 

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
