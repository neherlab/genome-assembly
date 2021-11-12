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

// combine the two fast5 channels
fast5_ch = fast5_loaded.concat(fast5_watcher)


process basecall {

    // publishDir params.basecall_dir, mode: 'move',
    //     saveAs: { "${params.basecall_dir}/${bcode}/${it}" }

    input:
        path fast5_file from fast5_ch

    output:
        path "**/*.fastq.gz" into fastq_ch
        val "${fast5_file.getSimpleName()}" into fastq_sourcename

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

fastq_ch.view()
fastq_sourcename.view()
