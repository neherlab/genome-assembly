import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import argparse
import pathlib


def selective_show(b):
    if b:
        plt.show()
    else:
        plt.close()


if __name__ == "__main__":

    # parse arguments
    parser = argparse.ArgumentParser(
        description="produce figures to analyze sequencing statistics"
    )
    parser.add_argument(
        "stats_file",
        type=str,
        help="The csv file containing the basecalling statistics.",
    )
    parser.add_argument(
        "--dest",
        type=str,
        help="Destination folder in which to save figures",
        default=".",
    )
    parser.add_argument(
        "--thr",
        type=int,
        help="Threshold number of reads to exclude barcodes in some plots",
        default=1000,
    )
    parser.add_argument(
        "--display",
        help="if specified figures are displayed when created.",
        action="store_true",
    )

    args = parser.parse_args()

    df_file = pathlib.Path(args.stats_file)
    sv_fld = pathlib.Path(args.dest)

    # import dataframe
    df = pd.read_csv(df_file)

    # for backward compatibility, to later be removed
    if " barcode" in df.columns:
        df = df.rename(columns={" barcode": "barcode"})

    # select the right barcode order
    bc_order = np.sort(df["barcode"].unique())
    df["barcode"] = pd.Categorical(df["barcode"], bc_order)

    # select barcodes with more than threshold reads
    n_reads = df["barcode"].value_counts()
    selected_bc = np.sort(n_reads[n_reads > args.thr].index.values)
    mask = df["barcode"].isin(selected_bc)

    # log-length distribution by barcode, normalized
    sns.histplot(
        data=df[mask],
        x="len",
        hue="barcode",
        hue_order=selected_bc,
        bins=1000,
        cumulative=True,
        stat="density",
        common_bins=True,
        common_norm=False,
        element="step",
        fill=False,
    )
    plt.xscale("log")
    plt.xlabel("read length (bp)")
    plt.tight_layout()
    plt.savefig(sv_fld / "len_cdf.png", facecolor="w", dpi=200)
    selective_show(args.display)

    # number of reads by barcode
    sns.histplot(data=df, x="barcode")
    plt.xticks(rotation=90)
    plt.ylabel("n. reads")
    plt.axhline(args.thr, ls=":", color="gray", label="threshold")
    plt.legend()
    plt.yscale("log")
    plt.tight_layout()
    plt.savefig(sv_fld / "n_reads.png", facecolor="w", dpi=200)
    selective_show(args.display)

    # total read length by barcode
    sns.histplot(data=df, x="barcode", weights="len")
    plt.xticks(rotation=90)
    plt.ylabel("tot. read length")
    plt.yscale("log")
    plt.tight_layout()
    plt.savefig(sv_fld / "tot_length.png", facecolor="w", dpi=200)
    selective_show(args.display)

    # read length distribution by barcode
    sns.boxplot(data=df[mask], x="barcode", y="len", order=selected_bc)
    plt.xticks(rotation=90)
    plt.yscale("log")
    plt.ylabel("read length distribution")
    plt.tight_layout()
    plt.savefig(sv_fld / "read_length_distr.png", facecolor="w", dpi=200)
    selective_show(args.display)
