
import sys
import pandas as pd
from Bio import SeqIO

if __name__ == "__main__":

    # The only argument is the fastq file to process
    assert len(sys.argv) == 2

    # extract the records
    with open(sys.argv[1], 'r') as f:
        records = list(SeqIO.parse(f, 'fastq'))
    
    data = []

    for record in records:
        # for every read capture length
        dt = {'len' : len(record)}

        # and barcode (or unclassified)
        desc = str.split(record.description)
        for dc in desc:
            if 'barcode=' in dc:
                dt['barcode'] = dc[len('barcode='):]
        data.append(dt)

    # assign timestamp to the batch
    df = pd.DataFrame(data)
    df['time'] = pd.Timestamp.now()

    # save in csv format
    df.to_csv('basecalling_stats.csv', index=False, header=True)
