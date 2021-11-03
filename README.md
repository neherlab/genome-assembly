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
