# Bacterial genome assembly pipeline written in Nextflow

## Pipeline structure

### Basecalling

The computer doing the sequencing should have a python script running that takes care of uploading to the cluster new `.fast5` files as soon as they get produced by the flowcell.

At the same time on the cluster another script should be running that takes care of starting the basecalling as soon as new files become available. This should be a `nextflow` script, that submits jobs using `SLURM`.
Basecalling is done using `guppy`. It should run on GPUs as this makes it much faster.
Each basecalling job will produce `fastq.gz` files, which are created in subfolders whose name `barcodexx` (where `xx` is the barcode number) indicate the barcode of the read. These files should be sorted on different folders according to this barcode.

Files corresponding to the same barcodes should then be merged into a single file, containing all of the sequences corresponding to this barcode. Once this step is completed, genome assembly can start.

#### Basecalling test dataset

The test dataset for basecalling was created by subsampling `.fast5` files from an old nanopore sequencing run. This was done using tools provided in [ont_fast_api](https://github.com/nanoporetech/ont_fast5_api). Each file should contain only 3 reads, to make the testing fast.

#### Basecalling command

```bash
netflow run basecall-draft.nf \
    --set_watcher false \ # to avoid activating the watcher
    -resume \ # to resume execution from last run
    -profile cpu \ # either cpu / gpu / local . The first two are for SLURM runs.
```

This will produce a report of the run in the `reports` folder

### Genome Assembly

The automatization should include filtering reads by length, subsampling reads, and running the different assemblers suggested in the trycycle guide.

At this point we should add a script that should recapitulate the data and produce information on the quality of contigs. The user can then decide which contigs should be submitted for the last processing step, which consists in reconciliation with trycycle.

### Folder structure

This is the general idea for the directory structure of the project

```
runs
    run_1
        input # input data
            001.fast5
            002.fast5
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
