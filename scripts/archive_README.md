# archive.py instructions

## Function of the script

This file is used to archive data in the group folder after basecalling (and genome assembly). It performs the follwing functions:

- archive raw `.fast5` files in a tar file in the `raw` destination folder.
- archive basecalled reads in the `basecalled` folder, in `fastq.gz` format.
- archive a symlink to the same data in the `experiments` folder, where data are organized based on experiment run, vial and sampling time-point. Archive also assembled genomes if present. 


## Structure of data storage

### Raw folder

The `raw` folder contains the raw `.fast5` files. Each different subfolder corresponds to a different nanopore sequencing run, with a name in the form `date_run-id` (e.g. `2022-03-01_FAL13933_18713141`). The date in this case is the _archiviation_ date, not the date of the experiment. This is done because in principle in the same sequencing run one might sequence data for different runs of the experiment. The run id is instead the prefix given to the `.fast5` files by nanopore. It includes the flowcell id and the id of the sequencing run, and is unique for each sequencing run.
Each of these subfolders contains:
- `fast5_reads.tar`: archive containing all of the fast5 files.
- `sample.csv`: a table containing information on how data for different barcodes is related to different experiments. For each barcode it is indicated the experiment id, the experiment date, the vial and timepoint of sampling, and also the sequencing run id which is the same for all the samples.


### Basecalled folder

The `basecalled` folder contains the basecalled reads for each sequencing run. Each sequencing run is saved in a separate subfolder, with the same naming convention used for the `raw` folder. Each subfolder contains:
- a list of `barcodeXX.fastq.gz` compressed fastq files, that contain all the reads relative to barcode `XX`.
- a `sample.csv` table relating the different barcodes to different experimental conditions, same as for the `raw` folder 


### Experiments folder

The `experiments` folder contains symlinks to the basecalled reads, but with a folder structure centered on experiments. The directory structure is in the form `experiments/experiment_tag/vial/timepoint/`. The `experiment_tag` is a string that concatenates the date of the experiment with the experiment id (e.g. `2020-02-18_morbidostat_run_2`). `vial` and `timepoint` indicate which vial of the morbidostat the data is relative to and which sampling time-point.
Inside the last layer of directories the following files are present:
- `reads.fastq.gz`: symlink to the corresponding gzipped fastq file in the `basecalled` folder
- `README.txt`: a readme file with information on the experimental conditions and the sequecning run that produced the data.
- `assembled_genome`: (optional) if the reads were transformed in an assembled and annotated genome, then the result is saved in this folder.


## Script usage

The script has the following usage:

```
usage: archive.py [-h] [--exp_id EXP_ID] [--date DATE] [--create_df] data_fld

Script to archive the data in the GROUP folder. The script will look for a `sample.csv` file containing information about the run. If the file is not found then a draft is automatically created for the user to complete.

positional arguments:
  data_fld         subfolder of `runs` containing the data to archive

optional arguments:
  -h, --help       show this help message and exit
  --exp_id EXP_ID  experiment id. If specified when creating `sample.csv` it sets the value of the `experiment_id` column
  --date DATE      experiment date. If specified when creating `sample.csv` it sets the value of the `date` column
  --create_df      force the creation of the `sample.csv` file.
```

When run the first time, the script will look for a `data_fld/sample.csv` file having the following columns:

|   barcode |   vial |   timepoint |   filesize (Mb) | valid   | flowcell_run_id   | experiment_id   | date       |
|----------:|-------:|------------:|----------------:|:--------|:------------------|:----------------|:-----------|
|         1 |    nan |         nan |          715.39 | True    | FAL13933_18713141 | RT              | 2022-02-18 |
|         5 |    nan |         nan |          317.29 | True    | FAL13933_18713141 | RT              | 2022-02-18 |
|         7 |    nan |         nan |          427.59 | True    | FAL13933_18713141 | RT              | 2022-02-18 |
|         9 |    nan |         nan |            0.12 | False   | FAL13933_18713141 | RT              | 2022-02-18 |
|        10 |    nan |         nan |            0.05 | False   | FAL13933_18713141 | RT              | 2022-02-18 |
|        11 |    nan |         nan |            0.06 | False   | FAL13933_18713141 | RT              | 2022-02-18 |
|        12 |    nan |         nan |            0.31 | False   | FAL13933_18713141 | RT              | 2022-02-18 |

If not found, then the script will create it and exit. The user can then manually modify the table to decide which barcodes should be included (`valid` column) and to link each barcode to an appropriate experiment (`experiment_id` and `date` columns) vial (`vial`) and time-point (`timepoint`). The `filesize (Mb)` is only displayed to help the user check which barcodes were not used (they will correspond to small files).

It will also be created if the `--create_df` flag is present. The options `--exp_id` and `--date` can be used to insert a particular value in the `experiment_id` and `date` columns for all entries.

If this table is present (and the user added vials and timepoints for each included barcode) the script will load it and ask the user for confirmation. Once the confirmation is provided, then the script will proceed to archive the corresponding fast5 files in the `raw` folder, the fastq files in the `basecalled` folder, and create the appropriate folder structure and symlinks in the `experiments` folder. It will also archive assembled genomes if the corresponding `prokka` folder is found.


