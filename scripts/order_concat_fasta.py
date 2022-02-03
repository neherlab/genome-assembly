import argparse
from Bio import SeqIO
import numpy as np


if __name__ == "__main__":

    # parse arguments
    parser = argparse.ArgumentParser(
        description="concatenates fasta files in a single file, with "
    )
    parser.add_argument(
        "--prefix",
        type=str,
        help="prefix of the output fasta file",
    )
    parser.add_argument(
        "files",
        type=argparse.FileType("r"),
        nargs="+",
        help="List of fasta files to concatenate",
    )

    args = parser.parse_args()

    # creat list of reads
    reads = []
    for f in args.files:
        r = SeqIO.read(f, format="fasta")
        reads.append(r)

    # sort reads by id
    reads = sorted(reads, key=lambda r: r.id)

    # write in a single fasta file with specified prefix
    with open(f"{args.prefix}.fasta", "w") as f:
        SeqIO.write(reads, f, format="fasta")
