#!/usr/bin/env nextflow


// --------- parameter definitions --------- 

// run for which the pipeline should be executed
params.run = 'test'

// guppy setup
params.flowcell = 'FLO-MIN106'
params.kit = 'SQK-LSK109'
params.barcode_kits = 'EXP-NBD114 EXP-NBD104'

// watch for incoming files
params.set_watcher = true


// --------- workflow --------- 

// guppy binaries
if (params.use_gpu) {
    params.guppy_bin = "$baseDir/guppy/guppy-gpu/bin/guppy_basecaller"
    // params.guppy_bin = "$baseDir/guppy/guppy-cuda/bin/guppy_basecaller"
} else {
    params.guppy_bin = "$baseDir/guppy/guppy-cpu/bin/guppy_basecaller"
}

// defines directories for input data and to output basecalled data
params.input_dir = file("runs/${params.run}/input")
params.basecall_dir = file("runs/${params.run}/basecalled")

// channel for already loaded fast5 files
fast5_loaded = Channel.fromPath("${params.input_dir}/*.fast5")

// watcher channel for incoming `.fast5` files.
// Terminates when `end-signal.fast5.xz` file is created.
if ( params.set_watcher ) {
    fast5_watcher = Channel.watchPath("${params.input_dir}/*.fast5")
                            .until { it.name ==~ /end-signal.fast5/ }
}
else { fast5_watcher = Channel.empty() }


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
        path "**/fastq_pass/barcode*/*.fastq.gz" into fastq_ch

    // beforeScript "${params.use_gpu} && module purge && module load CUDA"

    script:
        """
        ${params.guppy_bin} \
            -i . \
            -s . \
            --barcode_kits ${params.barcode_kits} \
            --flowcell ${params.flowcell} --kit ${params.kit} \
            --compress_fastq \
            --disable_pings \
            --nested_output_folder \
            --trim_barcodes \
        """

}

// Group results by barcode using the name of the parent
// folder in which files are stored (created by guppy)
fastq_barcode_ch = fastq_ch.flatten()
                    .map { x -> [x.getParent().getName(), x] }
                    .groupTuple()

// This process takes as input a tuple composed of a barcode
// and a list of fastq.gz files corresponding to that barcode.
// It decompresses and concatenates these files, returning
// a unique compressed filename that is named `barcodeXX.fastq.xz`,
// where `XX` is the barcode number
process concatenate_and_compress {

    publishDir params.basecall_dir, mode: 'move'
    // storeDir params.basecall_dir

    input:
        tuple val(barcode), file('reads_*.fastq.gz') from fastq_barcode_ch

    output:
        file "${barcode}.fastq.gz"

    script:
    """
    # decompress with gzip, concatenate and compress with gz
    gzip -dc reads_*.fastq.gz | gzip > ${barcode}.fastq.gz
    """
}