# Script to archive data in the group folder. See the corresponding README file for details on usage.

import argparse
import pathlib
import os
import re
import datetime
import subprocess
import numpy as np
import pandas as pd
import time

dest = pathlib.Path("/scicore/home/neher/GROUP/data/2022_nanopore_sequencing")
# dest = pathlib.Path("archive")
raw_main_dir = dest / "raw"
bc_main_dir = dest / "basecalled"
exp_main_dir = dest / "experiments"


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


def run_command(command, verbose=False):
    """Utility function to run a shell command and optionally visualize output."""
    subp = subprocess.run(command, capture_output=True)
    if subp.returncode:
        print(f"Error: return code {subp.returncode}")
        print("message:")
        print(subp.stderr.decode())
        raise RuntimeError(f"command {' '.join(command)} failed")
    else:
        if verbose:
            stdout = subp.stdout.decode()
            if len(stdout) > 0:
                print(stdout)


def create_fast5_archive(archive_fld, fast5_fld):
    """creates a `fast5_reads.tar.gz` file inside of `archive_fld` folder,
    containing all .fast5 files from `fast5_fld`. Returns the path of the
    created archive."""
    fast5_files = [f.name for f in fast5_fld.glob("*.fast5")]
    archive_file = archive_fld / "fast5_reads.tar"
    command = [
        "tar",
        "cvf",
        str(archive_file),
        "--directory=" + str(fast5_fld),
    ] + fast5_files
    run_command(command)
    return archive_file


def make_read_only(files):
    """given a list of files, runs chmod 444 to make them read-only."""
    file_names = [str(f) for f in files]
    run_command(["chmod", "444"] + file_names)


def mkdir_check_nonexistent(dir_path):
    """Check that a directory does not exist, and if so then creates it."""
    if dir_path.is_dir():
        raise FileExistsError(
            f"""The folder {dir_path} already exists.
        Remove it if you want to overwrite it."""
        )
    dir_path.mkdir()


def single_experiment_readme(subdir, df_row, git_id):
    """creates a README.txt file for the single experiment"""
    message = [
        "The reads for this condition:",
        f"\texperiment tag: {df_row.experiment_id}",
        f"\tdate: {df_row.date}",
        f"\tvial: {df_row.vial}",
        f"\ttimepoint: {df_row.timepoint}",
        "were produced in the sequencing run:",
        f"\tflowcell run: {df_row.flowcell_run_id}",
        f"\tbarcode: {df_row.barcode}",
        "The basecalling was performed using the workflow contained in:",
        "\thttps://github.com/neherlab/genome-assembly",
        f"\tcommit: {git_id}",
        "If the `assembled_genome` folder is present, genome assembly and ",
        "annotation was performed with the workflow present in the same repository.",
        "This assembly pipeline is based on trycycler (https://github.com/rrwick/Trycycler)",
        "And annotation was done using Prokka (https://github.com/tseemann/prokka).",
        "For reproducibility, the log of trycycler reconcile command is also saved.",
        "This contains information on which contigs were included in the assembly.",
    ]
    rdm_file = subdir / "README.txt"
    with open(rdm_file, "w") as f:
        f.write("\n".join(message))
    make_read_only([str(rdm_file)])


def lock_file(f):
    """creates a file.lock to signal the lock of the file"""
    lock_f = pathlib.Path(str(f) + ".lock")
    t = 0
    while t < 50:
        if lock_f.is_file():
            t += 1
            time.sleep(5)
        else:
            with open(lock_f, "w") as lf:
                lf.write(f"lock file created on {datetime.date.today().isoformat()}")
            return True
    raise RuntimeError(f"maximum waiting time exceeded when trying to lock {f}")


def unlock_file(f):
    """Unlocks a file by removing the corresponding lock file"""
    lock_f = pathlib.Path(str(f) + ".lock")
    assert lock_f.is_file(), "Lock file missing"
    os.remove(lock_f)


def copy_prokka_data(prokka_src, prokka_dest):
    """Copies and renames the content of the prokka folder."""
    # copy prokka output
    for f in prokka_src.glob("barcode*_genome.*"):
        new_file = prokka_dest / f"assembly{f.suffix}"
        run_command(["cp", str(f), str(new_file)])
        make_read_only([new_file])
    # copy reconcile_log for different clusters
    parent_dir = prokka_src.parent
    for f in parent_dir.glob("cluster_*"):
        cluster_id = f.name
        log_file_from = f / "reconcile_log.txt"
        log_file_to = prokka_dest / f"{cluster_id}_reconcile_log.txt"
        run_command(["cp", str(log_file_from), str(log_file_to)])
        make_read_only([log_file_to])


def get_git_commit_id():
    """Gets the current"""
    return subprocess.check_output(["git", "rev-parse", "HEAD"]).decode("ascii").strip()


def generate_seqdata_readme(dest_fld, df, filetype):
    """Generates the readme file for the `raw` and `basecalled` subfolders"""
    readme = dest_fld / "README.txt"

    fri = df["flowcell_run_id"].iloc[0]

    if filetype == "fast5":
        content = [
            "This folder contains raw fast5 files generated by nanopore sequencing.",
        ]
    elif filetype == "fastq":
        content = [
            "This folder contains basecalled nanopore reads in the form of compressed",
            "fastq files. Each file corresponds to a different barcode.",
        ]
    else:
        raise RuntimeError("filetype must be either fast5 or fastq")

    git_id = get_git_commit_id()
    content += [
        "\nThe data was generated by the nanopore sequencing run with id:",
        str(fri),
        "\nBasecalling, genome assembly and annotation was done with the workflow",
        "available in the repository:",
        "https://github.com/neherlab/genome-assembly",
        f"commit id: {git_id}",
        "\nThe file `sample.csv` contains a list of valid barcodes",
        "and their corresponding experimental condition (experiment id,",
        " vial, timepoint...).",
    ]
    with open(readme, "w") as f:
        f.write("\n".join(content))
    make_read_only([readme])


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
    read_sample_info_kwargs = {"dtype": {"barcode": int, "vial": str, "timepoint": str}}
    df = pd.read_csv(sample_info_file, **read_sample_info_kwargs)
    print(df)
    check_valid(df)

    # ask for confirmation before data archiviation
    answer = input(
        "\n".join(
            [
                "Confirm? [y/yes to accept]",
                "Nb: only barcodes where valid==True will be transferred.\n",
            ]
        )
    )
    if not (answer.lower() in ["y", "yes"]):
        print("Aborting data archiviation.")
        exit(0)

    # select only barcodes to be transferred and filter dataframe to relevant columns:
    df = filter_dataframe(df)

    # -------------- archive fast5 files ---------------------
    print("\n ---- Creating fast5 file archive ----")

    # name for fast5 files storage folder
    flow_id = df["flowcell_run_id"].iloc[0]
    today = datetime.date.today().isoformat()
    flow_run_tag = f"{today}_{flow_id}"
    archive_fld = raw_main_dir / flow_run_tag
    git_id = get_git_commit_id()

    # check that folder does not already exist and create it
    mkdir_check_nonexistent(archive_fld)

    # list of created directories for log
    created_dirs = [archive_fld]

    # list entries to archive
    print("archiving the following entries:")
    print(df)

    # copy fast5 files in tar archive
    print(f"creating fast5 archive in {archive_fld}...")
    print(f"this might take some time...")
    fast5_fld = data_fld / "input"
    fast5_archive = create_fast5_archive(archive_fld, fast5_fld)

    # add copy of sample.csv file
    stats_file = archive_fld / "sample.csv"
    print(f"saving sample information on {stats_file}...")
    df.to_csv(stats_file, index=False)

    # add a readme file
    generate_seqdata_readme(archive_fld, df, filetype="fast5")

    # change permissions to read-only
    change_permissions_to = [fast5_archive, stats_file]
    make_read_only(change_permissions_to)

    # -------------- archive fastq reads ---------------------
    print("\n ---- Copying compressed fastq files for selected barcodes ----")

    # create folder to store reads (check that it does not exist already)
    fastq_to_fld = bc_main_dir / flow_run_tag
    mkdir_check_nonexistent(fastq_to_fld)

    created_dirs.append(fastq_to_fld)  # for later logging

    # transfer fastq reads to basecalled folder
    fastq_from_fld = data_fld / "basecalled"
    print(f"copy selected barcodes from {fastq_from_fld} to {fastq_to_fld}")
    fastq_to_files = {}  # dictionary with files destinations
    for bc in df.barcode.values:
        print(f"processing barcode {bc}")
        fastq_from_file = fastq_from_fld / f"barcode{int(bc):02d}.fastq.gz"
        assert fastq_from_file.is_file(), f"file {fastq_from_file} does not exist."
        fastq_to_files[bc] = fastq_to_fld / f"barcode{int(bc):02d}.fastq.gz"
        # copy fastq files
        run_command(["cp", str(fastq_from_file), str(fastq_to_files[bc])])

    sample_info_file = fastq_to_fld / "sample.csv"
    print(f"creating info table {sample_info_file}")
    df.to_csv(sample_info_file, index=False)

    # change file permissions
    readonly_files = [str(f) for f in fastq_to_files.values()] + [str(sample_info_file)]
    make_read_only(readonly_files)

    # add readme file
    generate_seqdata_readme(fastq_to_fld, df, filetype="fastq")

    # -------------- create experiment database with links ---------------------
    print("\n ---- Creating directories and links in experiments folder ----")

    # find pairs of date/experiment_id
    pairs = df[["experiment_id", "date"]].value_counts().index.to_list()
    for exp_id, date in pairs:

        print(f"processing experiment {exp_id} date {date}")

        # select only data
        mask = (df.experiment_id == exp_id) & (df.date == date)
        sdf = df[mask].copy()

        # define experiment folder and create it if it does not exist
        exp_tag = f"{date}_{exp_id}"
        exp_dir = exp_main_dir / exp_tag
        if not exp_dir.is_dir():
            created_dirs.append(exp_dir)
        exp_dir.mkdir(exist_ok=True)

        # for every barcode
        for idx, row in sdf.iterrows():
            bc, vial, tp = row.barcode, row.vial, row.timepoint
            print(f"processing barcode {bc}, vial {vial}, timepoint {tp}")

            # create experiment vial/timepoint subdirectory
            exp_subdir = exp_dir / f"vial_{int(vial):02d}" / f"time_{tp}"
            assert not exp_subdir.is_dir(), f"the directory {exp_subdir} already exists"
            exp_subdir.mkdir(parents=True)
            created_dirs.append(exp_subdir)

            # create symbolic link to reads, and make it read-only
            link_file = exp_subdir / "reads.fastq.gz"
            command = ["ln", "-s", fastq_to_files[bc].resolve(), str(link_file)]
            run_command(command)
            make_read_only([str(link_file)])

            single_experiment_readme(exp_subdir, row, git_id)

            # if present, copy the prokka folder containing annotated genome
            prokka_fld_src = (
                data_fld
                / "clustering"
                / f"barcode{int(bc):02d}"
                / f"prokka_barcode{int(bc):02d}"
            )
            if prokka_fld_src.is_dir():
                print("copying assembled and annotated genome")
                prokka_dest = exp_subdir / "assembled_genome"
                prokka_dest.mkdir()
                copy_prokka_data(prokka_fld_src, prokka_dest)

        # check if sample.csv already exists, if so merge and overwrite
        sample_info = exp_dir / "sample.csv"
        if sample_info.is_file():
            print(f"appending to table {sample_info}")
            lock_file(sample_info)
            old_df = pd.read_csv(sample_info, **read_sample_info_kwargs)
            new_df = pd.concat([sdf, old_df], ignore_index=True)
            run_command(["chmod", "666", str(sample_info)])
            new_df.to_csv(sample_info, index=False)
            unlock_file(sample_info)
        else:
            print(f"creating table {sample_info}")
            sdf.to_csv(sample_info, index=False)

        # making the file read-only
        run_command(["chmod", "444", str(sample_info)])

    print("\n ---- Data successfully archived ----\n")
    print("the following folders were created:")
    for fold in created_dirs:
        print(fold)
