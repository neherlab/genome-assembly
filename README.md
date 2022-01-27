# Bacterial genome assembly pipeline

This repo contains a set of [Nextflow](https://www.nextflow.io/) workflows to automatize basecalling and assembling bacterial genomes from Nanopore sequencing. It can be run in parallel for different barcodes, and uses the SLURM protocol to dispatch jobs on a cluster. It is based on [trycycler](https://github.com/rrwick/Trycycler). This is currently a work in progress.

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
netflow run basecall-draft.nf \
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


### 1. Automatic syncing of files from a client machine (where data is produced) to the server (where data is consumed):

 - On the client machine: open `./scripts/watch-client` and adjust these variables:

    ```bash
    # Directory to watch. Files That appear in this directory will be sent.
    WATCH_DIR="/some/absolute/client/path/"
    # or
    WATCH_DIR="${THIS_DIR}/../some/relative/client/path/"

    # Username on the server. The SSH session will be established for this user.
    SERVER_USERNAME="ubuntu"

    # Directory on the server to which the files will be placed
    SERVER_DIR="/home/${SERVER_USERNAME}/files"

    # Server IP address or hostname
    SERVER_ADDRESS="18.158.45.194"
    ```

 - On the client machine: send SSH key to the server, so that SSH sessions could be established without password

    ```bash
    ssh-copy-id username@12.34.56.78
    ```

 - On the client machine: Run `./scripts/watch-client`

 - On the server machine: list files on the server by issuing an ls command every 0.5 seconds:

    ```bash
    watch -ctn 0.5 -- ls -alhR /the/server/directory
    ```

 - On the client machine: Go to watch directory (defined as `${WATCH_DIR}`) and make a 0-size file:

    ```bash
    touch empty.txt
    ```

 - On the server machine: Note that the file appeared on the server and is listed by the `ls` command, having size 0

 - On the client machine: Go to watch directory (defined as `${WATCH_DIR}`) and make a 0-size file:

    ```bash
    fallocate -l 1G files/aaa/11.txt
    ```

 - On the server machine: Note that the file appeared on the server, and is listed by the `ls` command, has a random suffix in the filename and with size growing until filly downloaded. After that the file is renamed to the original name.


### 2. Watch files in a directory (on server machine) and run a command when a file changes:

 - Modify `${WATCH_DIR}` in `./scripts/watch-server` to point to the directory that should be watched

 - On the server machine: Run `./scripts/watch-server`

 - On the server machine: Go to watch directory (defined as `${WATCH_DIR}` in the script) and create some files with `touch` and `fallocate` as described above.

 - Note that these modifications are printed by the `./scripts/watch-server`  script.

 - Modify the bash command at the bottom of the `./scripts/watch-server` to run any required command instead of (ar additional to) `echo` and using the variables provided by `watchexec`, e.g. `./my-awesome-command --input=${WATCHEXEC_CREATED_PATH}"`. The newly created files should now trigger that command and the  `${WATCHEXEC_CREATED_PATH}` will be substituted by the path of the created file.


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

TODO: add tools to automatically install dependencies (e.g. conda environments within nextflow).