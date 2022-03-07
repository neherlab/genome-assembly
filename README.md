# Bacterial genome assembly pipeline

This repo contains a set of [Nextflow](https://www.nextflow.io/) workflows to automatize basecalling and assembling bacterial genomes from Nanopore sequencing. It can be run in parallel for different barcodes, and uses the SLURM protocol to dispatch jobs on a cluster. It is based on [trycycler](https://github.com/rrwick/Trycycler). This is currently a work in progress.

## Setup

- initialize the conda environment in `conda_env.yml`
- run the `scripts/setup.sh` script that will download `miniasm_and_minipolish.sh`
- download `guppy` binaries.

## Pipeline structure

The pipeline is divided in different steps, each one corresponding to a different Nextflow workflow. The ones developed so far are, in order:

- basecalling
- assembling
- reconcile
- consensus

### Basecalling

The computer doing the sequencing should have a python script running that takes care of uploading to the cluster new `.fast5` files as soon as they get produced by the flowcell.

At the same time on the cluster another script should be running that takes care of starting the basecalling as soon as new files become available. This should be a `nextflow` script, that submits jobs using `SLURM`.
Basecalling is done using `guppy`. It should run on GPUs as this makes it much faster.
Each basecalling job will produce `fastq.gz` files, which are created in subfolders whose name `barcodexx` (where `xx` is the barcode number) indicate the barcode of the read. These files should be sorted on different folders according to this barcode.

Files corresponding to the same barcodes should then be merged into a single file, containing all of the sequences corresponding to this barcode. Once this step is completed, genome assembly can start.

#### Basecalling test dataset

The test dataset for basecalling was created by subsampling `.fast5` files from an old nanopore sequencing run. This was done using tools provided in [ont_fast_api](https://github.com/nanoporetech/ont_fast5_api). Each file should contain only 3 reads, to make the testing fast.

#### Basecalling command

Example of pipeline execution command and options

```bash
nextflow run basecall.nf \
    -resume \
    -profile cluster \
    --set_watcher false \
    --use_gpu false \
    --run test_run \
    --live_stats true \
    --guppy_bin_cpu my_guppy_location/guppy_basecaller
```

The options have the following meaning:

- `-resume`: to optionally resume execution if it was stopped.
- `-profile cluster`: either cluster or standard, depending on whether execution should happen locally or in SLURM jobs.
- `--set_watcher false`: if true then new files that are uploaded in the `input` folder during execution are also processed. In this case the watcher is stopped when a mock file named `end-signal.fast5` is created in the folder. This is necessary to continue with the next steps of the process, for which all files are required.
- `--use_gpu false`: whether to proceed to perform basecalling on cpu or gpu. For gpu execution the location of the binary must be specified with `--guppy_bin_gpu path_to_binary/guppy_basecaller`.
- `--run test_run`: the name of the run. This corresponds to the name of the sub-folder in the `runs` folder, which contains the data in a further `input` folder (see below for folder structure).
- `--live_stats true`: whether to produce a `bc_stats.csv` file containing stats on length and barcode of the reads produced so far.
- `--guppy_bin_cpu my_guppy_location/guppy_basecaller`: location of the binaries for guppy.

Other options that can be specified include `--flowcell`, `--kit` and `--barcode_kits`.

### Ending the basecalling script:

Create a file named `end-signal.fast5` in the local `READS` folder of the watcher script. This will terminate the nextflow process.

The upload script can be terminated using `Ctrl-C` or `Ctrl-D`.

#### Visualizing basecalling statistics

The script `basecall_stats.py` can be used to generate figures to analyze general basecalling statistics, such as read length distribution and number of reads. Usage is as follows:

```
usage: generate_plots.py [-h] [--dest DEST] [--thr THR] [--display] stats_file

produce figures to analyze sequencing statistics

positional arguments:
  stats_file   The csv file containing the basecalling statistics.

optional arguments:
  -h, --help   show this help message and exit
  --dest DEST  Destination folder in which to save figures
  --thr THR    Threshold number of reads to exclude barcodes in some plots
  --display    if specified figures are displayed when created.
```

### Assemble

The `assemble` workflow takes care of assembling genomes following trycyler's procedure. It can be run with: 

```bash
nextflow run assemble.nf \
  -profile cluster \
  --run test_run \
  -resume
```

As for basecalling, the `-profile` option can be set to either `cluster` or `standard`, the latter is for a local execution.

### Reconcile

The `trycycle reconcile` step is executed by the `reconcile.nf` workflow. This workflow tries to reconcile in parallel al clusters for all barcodes. It produces a `reconcile_log.txt` file for each cluster, with the output of the command. This file can be used to correct the dataset and possibly remove some contigs. It also produces a `reconcile_summary.txt` file in the `clustering` folder, with a summary of which clusters have been successfully reconciled.

This command should be run multiple times with the `-resume` option, correcting every time the content of the clusters that failed to reconcile, until all clusters are successfully reconciled.

```bash
nextflow run reconcile.nf \
  -profile cluster \
  --run test_run \
  -resume
```

### Consensus

The workflow `consensus.nf` takes care of building a consensus read. It also polisheds the genome using `medaka` and adds annotations with `prokka`.

```bash
nextflow run consensus.nf \
   -profile cluster \
   --run test_run \
   -resume
```

Nb: if the computational node has no access to the internet, `medaka` could fail because it cannot download the appropriate model `r941_min_high_g360`. In this case on the login node, where internet is available, one must manually (only once) download the model. This can be done in the following two steps:

1. Activate the conda environment for `medaka`. The environment is created by nextflow and stored in the `work/conda` folder. One can retrieve its location also by running `conda env list`.
2. Once the corresponding conda environment is activated, the model can be installed by running `medaka tools download_models --models r941_min_high_g360`

## Folder structure

This is the general idea for the directory structure of the project. Before running the first workflow (or while running it if `set_watcher` is set to true) data should be placed inside the `run_name/input` folder.

```
runs
    run_1
        input # input data
            001.fast5
            002.fast5
            ...
        basecalled # basecalled data (fastq.gz)
            barcode_12.gz
            barcode_13.gz
            ...
        clustering # further processing
    run_2
       input
       basecalled
       ... 
    ...
```

## Helper scripts

## archive.py

This script is used to archive the result of basecalling nanopore reads to the proper folder the cluster.
For details on how to use it see `scripts/archive_README.md`.

## Dependencies

List of dependencies used in the pipeline so far:

- `nextflow`
- `trycycler`
- `raven`
- [Miniasm+Minipolish](https://github.com/rrwick/Minipolish)
- `flye`
- `any2fasta`
- `filtlong`
- `guppy`
- `medaka`
- `prokka`
