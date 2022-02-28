# Intructions on usage of archive.py

This file is used to archive data in the group folder after basecalling (and genome assembly). It performs the follwing functions:

- archive raw `.fast5` files in the `raw` destination folder, in compressed format
- 

It has the following usage:

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

TODO:
- problem with date: archived using today date but experiment with experiment date. The mapping is not a problem: flowcell_run_id is unique