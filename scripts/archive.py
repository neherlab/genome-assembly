# Script to archive data in the group folder, organized by experiment, vial and sampling
# time-point. It takes as argument a csv table

# TODO: archive csv file with addition of experiment id and flowcell sequencing sample id.
# TODO: create destination folder if it does not exist
# TODO: change permissions to read-only

import argparse
import pathlib
import os
import re
import datetime
from shutil import ExecError
import subprocess
import numpy as np
import pandas as pd

# dest = pathlib.Path("~/GROUP/data/2022_nanopore_sequencing/")
dest = pathlib.Path("archive")
raw_dir = dest / "raw"
bc_dir = dest / "basecalled"
exp_dir = dest / "experiments"


def extract_flowcell_run_id(data_fld):
    """Extracts the flowcell run id from the fast5 files prefix."""
    for child in (data_fld / "input").glob("*_1.fast5"):
        match = re.search(r"(.*)_1.fast5", child.name)
        return match.group(1)


def extract_barcodes(data_fld):
    """Explores the `basecalled` folders and returns a list of numbers of the
    `barcodeXX.fastq.gz` files. It also returns the corresponding list of file
    sizes."""
    barcodes, filesizes = [], []
    for child in (data_fld / "basecalled").glob("barcode*.fastq.gz"):
        match = re.search(r"barcode(\d+).fastq.gz", child.name)
        barcodes.append(match.group(1))
        filesizes.append(child.stat().st_size)
    order = np.argsort(barcodes)
    barcodes = np.array(barcodes)[order]
    filesizes = np.array(filesizes)[order]
    return barcodes, filesizes


def initialize_sample_df(data_fld, args):
    """Initializes a dataframe containing sample information, to be later
    completed by the user."""
    barcodes, filesizes = extract_barcodes(data_fld)
    flowcell_run_id = extract_flowcell_run_id(data_fld)

    df = pd.DataFrame(barcodes, columns=["barcode"])
    df["vial"] = np.nan
    df["timepoint"] = np.nan
    df["filesize (Mb)"] = np.round(filesizes / (1024**2), 2)
    df["valid"] = df["filesize (Mb)"] > 10
    df["flowcell_run_id"] = flowcell_run_id
    if args.exp_id is None:
        df["experiment_id"] = np.nan
    else:
        df["experiment_id"] = args.exp_id

    if args.date is None:
        df["date"] = np.nan
    else:
        df["date"] = args.date
    return df


def check_valid(df):
    """Checks that the dataframe has all the necessary columns, that the
    `flowcell_run_id` column is the same for all entries,
    and that for all valid barcodes, both vial and timepoint are specified."""
    columns = set(
        [
            "barcode",
            "vial",
            "timepoint",
            "filesize (Mb)",
            "valid",
            "flowcell_run_id",
            "experiment_id",
            "date",
        ]
    )
    assert (
        set(df.columns) == columns
    ), "some of the required columns of the dataframe is missing."
    mask = df.valid
    assert np.all(
        df["flowcell_run_id"] == df["flowcell_run_id"][0]
    ), "the flowcell run id must be the same for all entries"
    assert not np.any(
        df.vial[mask].isna()
    ), "some vials for valid barcodes were not specified"
    assert not np.any(
        df.timepoint[mask].isna()
    ), "some timepoints for valid barcodes were not specified"


def filter_dataframe(df):
    """Keep only relevant barcodes and filter out irrelevant columns"""
    df = df[df.valid].copy()
    df = df.drop(columns=["filesize (Mb)", "valid"])
    return df


def run_command(command):
    """Utility function to run a shell command and visualize output."""
    subp = subprocess.run(command, capture_output=True)
    if subp.returncode:
        print(f"Error: return code {subp.returncode}")
        print("message:")
        print(subp.stderr.decode())
        raise ExecError(f"command {' '.join(command)} failed")
    else:
        print(subp.stdout.decode())


def create_fast5_archive(archive_fld, fast5_fld):
    """creates a `fast5_reads.tar.gz` file inside of `archive_fld` folder,
    containing all .fast5 files from `fast5_fld`. Returns the path of the
    created archive."""
    fast5_files = [f.name for f in fast5_fld.glob("*.fast5")]
    archive_file = archive_fld / "fast5_reads.tar.gz"
    command = [
        "tar",
        "cvzf",
        str(archive_file),
        "--directory=" + str(fast5_fld),
    ] + fast5_files
    run_command(command)
    return archive_file


if __name__ == "__main__":

    # argument parser
    parser = argparse.ArgumentParser(
        description="""Script to archive the data in the GROUP folder.
        The script will look for a `sample.csv` file containing information
        about the run. If the file is not found then a draft is automatically
        created for the user to complete."""
    )
    parser.add_argument(
        "data_fld",
        type=str,
        help="subfolder of `runs` containing the data to archive",
    )
    parser.add_argument(
        "--exp_id",
        help="""experiment id. If specified when creating `sample.csv` it sets
        the value of the `experiment_id` column""",
        type=str,
        required=False,
    )
    parser.add_argument(
        "--date",
        help="""experiment date. If specified when creating `sample.csv` it sets
        the value of the `date` column""",
        type=str,
        required=False,
    )
    parser.add_argument(
        "--create_df",
        help="force the creation of the `sample.csv` file.",
        action="store_true",
    )

    # parse arguments
    args = parser.parse_args()
    data_fld = pathlib.Path(args.data_fld)

    assert data_fld.is_dir(), "The data folder must be a directory"

    # preliminary check: csv file exists?
    sample_info_file = data_fld / "sample.csv"
    if not sample_info_file.is_file() or args.create_df:
        # if not create it
        print(f"`sample.csv` file does not exist. Creating it inside of `{data_fld}`")
        df = initialize_sample_df(data_fld, args)
        print(df)
        df.to_csv(sample_info_file, index=False)
        print(f"dataframe saved in {sample_info_file}")
        exit(0)

    # if the csv file exists then load it and check if it is valid
    df = pd.read_csv(sample_info_file)
    print(df)
    check_valid(df)

    # ask for confirmation before data archiviation
    answer = input(
        """Confirm? [y/yes to accept]
    Nb: only barcodes where valid==True will be transferred.\n"""
    )
    if not (answer.lower() in ["y", "yes"]):
        print("Aborting data archiviation.")
        exit(0)

    # select only barcodes to be transferred and filter dataframe to relevant columns:
    df = filter_dataframe(df)

    # -------------- archive fast5 files ---------------------

    # name for fast5 files storage folder
    flow_id = df["flowcell_run_id"][0]
    today = datetime.date.today().isoformat()
    archive_fld = raw_dir / f"{today}_{flow_id}"

    # check that folder does not already exist and create it
    if archive_fld.is_dir():
        raise FileExistsError(
            f"""The folder {archive_fld} already exists.
        Remove it if you want to overwrite it."""
        )
    archive_fld.mkdir()

    print("archiving the following entries:")
    print(df)

    # copy and compress fast5 files
    print(f"creating compressed fast5 archive in {archive_fld}...")
    fast5_fld = data_fld / "input"
    fast5_archive = create_fast5_archive(archive_fld, fast5_fld)

    # add copy of sample.csv file
    stats_file = archive_fld / "sample.csv"
    print(f"saving sample information on {stats_file}...")
    df.to_csv(stats_file, index=False)

    # TODO: add README

    # changing permissions
    print(
        f"changing file permissions to read-only to {fast5_archive} and {stats_file}..."
    )
    run_command(["chmod", "444", str(fast5_archive), str(stats_file)])

    # TODO: add README/section in group wiki

    # -------------- archive fastq reads ---------------------

    # TODO: next: create a folder for the sequencing run with the same name, and
    # move reads with barcode names (fastq.gz files) and save stats file.
    # and change permissions to read-only

    # -------------- create experiment database with links ---------------------

    # find pairs of date/experiment_id
    pairs = df[["experiment_id", "date"]].value_counts().index.to_list()
    for exp_id, date in pairs:

        # select only data
        mask = (df.experiment_id == exp_id) & (df.date == date)
        sdf = df[mask]

    # TODO: check that file does not already exist
    # exp_subdir = exp_dir /
    # print(f"creating folder")

    # TODO: create subfolder for basecalled reads, name = basecalling run id
    # TODO: move fastq file with all basecalled read. Rename according to

    # TODO: create experiment subfolder
    # TODO: link files
    # TODO: transfer prokka folder (which files?) if existing
