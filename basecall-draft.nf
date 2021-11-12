#!/usr/bin/env nextflow

// run for which the pipeline should be executed
params.run = 'test'
params.input_dir = file("runs/${params.run}/input")
params.basecall_dir = file("runs/${params.run}/basecalled")

params.guppy_bin = "$baseDir/ont-guppy-cpu/bin/guppy_basecaller"
params.flowcell = 'FLO-MIN106'
params.kit = 'SQK-LSK109'

// create basecall directory if not existing
if ( ! params.basecall_dir.exists() ) {
    params.basecall_dir.mkdirs()
}


// channel for already loaded fast5 files
fast5_loaded = Channel.fromPath("${params.input_dir}/*.fast5")
// watcher channel for incoming fast5. Terminates when 'end-signal.fast5.xz' file is created
fast5_watcher = Channel.watchPath("${params.input_dir}/*.fast5")
                        .until { it.name ==~ /end-signal.fast5/ }

// for debug purpose, do not activate watcher
// fast5_watcher = Channel.empty()


// combine the two fast5 channels
fast5_ch = fast5_loaded.concat(fast5_watcher)


// Process that for any input fast5 file uses guppy
// to perform basecalling and barcoding. The output
// channel collects a list of files in the form
// .../barcodeXX/filename.fastq.gz
process basecall {

    input:
        path fast5_file from fast5_ch

    output:
        path "**/barcode*/*.fastq.gz" into fastq_ch

    script:
        """
        ${params.guppy_bin} \
            -i . \
            --barcode_kits EXP-NBD114 EXP-NBD104 \
            --compress_fastq \
            -s . \
            --disable_pings \
            --nested_output_folder \
            --trim_barcodes \
            --flowcell ${params.flowcell} --kit ${params.kit}
        """

}

// Group results by barcode using the name of the parent
// folder in which files are stored (created by guppy)
fastq_barcode_ch = fastq_ch.flatten()
                    .map {
                        x -> [x.getParent().getName(), x]
                    }
                    .groupTuple()

// This process takes as input a tuple composed of a barcode
// and a list of fastq.gz files corresponding to that barcode.
// It decompresses and concatenates these files, returning
// a unique compressed filename that is named `barcodeXX.fastq.xz`,
// where `XX` is the barcode number
process concatenate_and_compress {

    publishDir params.basecall_dir, mode: 'move'

    input:
        tuple val(barcode), file('reads_*.fastq.gz') from fastq_barcode_ch

    output:
        file "${barcode}.fastq.xz"

    script:
    """
    # decompress with gzip, concatenate and compress with xz
    gzip -dc reads_*.fastq.gz | xz > ${barcode}.fastq.xz
    """
}