#!/usr/bin/env nextflow


// --------- parameter definitions --------- 

// run for which the pipeline should be executed
params.run = 'test'

// guppy setup
params.flowcell = 'FLO-MIN106'
params.kit = 'SQK-LSK109'
params.barcode_kits = '"EXP-NBD114 EXP-NBD104"'

// watch for incoming files
params.set_watcher = true

// defines directories for input data and to output basecalled data
params.input_dir = file("runs/${params.run}/input")
params.basecall_dir = file("runs/${params.run}/basecalled")

// get a csv file with number of reads per barcode and time
// that gets updated online
params.live_stats = false

// whether to use gpu
params.use_gpu = false

// path of guppy binaries (cpu or gpu)
params.guppy_bin_cpu = "$baseDir/guppy_bin/guppy_basecaller_cpu"
// params.guppy_bin_cpu = "~/ONT_software/ont-guppy-cpu/bin/guppy_basecaller"
params.guppy_bin_gpu = "$baseDir/guppy_bin/guppy_basecaller_gpu"
// params.guppy_bin_gpu = "~/ONT_software/ont-guppy-gpu/bin/guppy_basecaller"

// --------- workflow --------- 

// guppy binaries
params.guppy_bin = params.use_gpu ? params.guppy_bin_gpu : params.guppy_bin_cpu

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
// .../(barcodeXX|unclassified)/filename.fastq.gz
params.add_device = params.use_gpu ? '--device auto' : ''
process basecall {

    label params.use_gpu ? 'gpu_q30m' : 'q6h'

    input:
        path fast5_file from fast5_ch

    output:
        path "**/fastq_pass/*/*.fastq.gz" optional true into fastq_ch


    script:
        """
        # ${params.use_gpu} && module purge && module load CUDA

        ${params.guppy_bin} \
            -i . \
            -s . \
            --barcode_kits ${params.barcode_kits} \
            --flowcell ${params.flowcell} --kit ${params.kit} \
            --compress_fastq \
            --disable_pings \
            --nested_output_folder \
            --trim_barcodes \
            ${params.add_device} \
            
        """

}

// Group results by barcode using the name of the parent
// folder in which files are stored (created by guppy)
fastq_barcode_ch = fastq_ch.flatten()
                    .tap { fastq_tap_ch }
                    .map { x -> [x.getParent().getName(), x] }
                    .groupTuple()

// This process takes as input a tuple composed of a barcode
// and a list of fastq.gz files corresponding to that barcode.
// It decompresses and concatenates these files, returning
// a unique compressed filename that is named `barcodeXX.fastq.gz`,
// where `XX` is the barcode number
process concatenate_and_compress {

    label 'q6h'

    publishDir params.basecall_dir, mode: 'move'

    input:
        tuple val(barcode), file('reads_*.fastq.gz') from fastq_barcode_ch

    output:
        file "${barcode}.fastq.gz"

    script:
    """
    # decompress with gzip, concatenate and compress with gz
    gzip -dc reads_*.fastq.gz | gzip -c > ${barcode}.fastq.gz
    """
}

// directory to store live statistics on the basecalling
params.bcstats_dir = file("runs/${params.run}/basecalling_stats")

// if live_stats is set to true, create a file to contain the stats
if (params.live_stats) {
    // create directory
    params.bcstats_dir.mkdirs()
    // create csv stats file and write header
    bc_stats_file = file("${params.bcstats_dir}/bc_stats.csv")
    bc_stats_file.text = 'len,barcode,time\n'
}

// Create the input channel for the stat as a mix of a channel with a single file
// and the feedback channel
bc_stats_init = Channel.fromPath("${params.bcstats_dir}/bc_stats.csv")
feedback_ch = Channel.create()
bc_stats_in = bc_stats_init.mix( feedback_ch )

// creates a csv file with read length, barcode and timestamp
// content of the file get appended to the file "bc_stats.csv"
// The feedback loop avoids that multiple threads try to append
// text on the same file.
process basecalling_live_report {

    label 'q30m'

    publishDir params.bcstats_dir, mode: 'copy'

    input:
        file('reads_*.fastq.gz') from fastq_tap_ch.collate(50)
        file('bc_stats.csv') from bc_stats_in

    output:
        file('bc_stats.csv') into feedback_ch

    when:
        params.live_stats

    script:
        """
        gzip -dc reads_*.fastq.gz > reads.fastq
        python3 $baseDir/scripts/basecall_stats.py reads.fastq
        tail -n +2 basecalling_stats.csv >> bc_stats.csv
        rm reads.fastq
        """
}