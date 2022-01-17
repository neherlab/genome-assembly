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

Example of pipeline execution command and options

```bash
netflow run basecall-draft.nf \
    --set_watcher false \ # to avoid activating the input-files watcher
    -resume \ # to resume execution from last run
    -profile cluster \ # either cluster or standard.
    --use_gpu false \ # whether to use gpu for basecalling
    --run 2021-11-17_test \ # name of the sub-folder in which files are stored
    --live_stats true \ # whether to produce live stats in a .csv file
```

This command will also automatically produce a report of the run in the `reports` folder.
The path of guppy binaries for cpu and gpu can be specified with `--guppy_bin_cpu` and `--guppy_bin_gpu`.
Other options that can be specified include `--flowcell`, `--kit` and `--barcode_kits`.

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
            barcode_12.gz
            barcode_13.gz
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
- `raven`
- [Miniasm+Minipolish](https://github.com/rrwick/Minipolish)
- `flye`
- `trycycler`
- `any2fasta`
- `filtlong`
- `guppy`

TODO: add tools to automatically install dependencies (e.g. conda environments within nextflow).