#!/usr/bin/env nextflow

// run for which the pipeline should be executed
params.run = 'test'
params.input_dir = file("runs/${params.run}/input")
params.basecall_dir = file("runs/${params.run}/basecalled")

params.guppy_bin = '/home/marco/ownCloud/neherlab/code/genome-assembly/ont-guppy-cpu/bin/guppy_basecaller'
params.flowcell = 'FLO-MIN106'
params.kit = 'SQK-LSK109'

// create basecall directory if not existing
if ( ! params.basecall_dir.exists() ) {
    params.basecall_dir.mkdirs()
}


// channel for already loaded fast5 files
fast5_loaded = Channel.fromPath("${params.input_dir}/barcode*/*fast5.xz")
// watcher channel for incoming fast5. Terminates when 'end-signal.fast5.xz' file is created
fast5_watcher = Channel.watchPath("${params.input_dir}/barcode*/*.fast5.xz")
                        .until { it.name ==~ /end-signal.fast5.xz/ }

// combine the two fast5 channels
fast5_all = fast5_loaded.concat(fast5_watcher)


// retrieve both file name and barcode path. e.g:
// [/home/.../b.fast5.xz, b, barcode22]
fast5_ch = fast5_all.map { x -> tuple(
                                x,
                                x.getSimpleName(),
                                x.getParent().getName())
                         }

process basecall {

    publishDir params.basecall_dir, mode: 'move',
        saveAs: { "${params.basecall_dir}/${bcode}/${it}" }

    input:
        set file(fast5_file), fname, bcode from fast5_ch

    output:
        file "${fname}.fastq.xz" into fastq_ch

    script:
    """
    xz -dkc $fast5_file > ${fname}.fast5
    echo ${fname}.fast5 | \
        ${params.guppy_bin} \
        --compress_fastq \
        -s . \
        --flowcell ${params.flowcell} --kit ${params.kit}
    rm ${fname}.fast5
    """

}

// fast5_split.view()