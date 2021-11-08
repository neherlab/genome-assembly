#!/usr/bin/env nextflow

// run for which the pipeline should be executed
params.run = 'test'

// channel for already loaded fast5 files
fast5_loaded = Channel.fromPath("runs/${params.run}/input/barcode*/*fast5.xz")
// watcher channel for incoming fast5. 
// Terminates when 'end-signal.fast5.xz' file is loaded
fast5_watcher = Channel.watchPath("runs/${params.run}/input/barcode*/*.fast5.xz")
                        .until { it.name ==~ /end-signal.fast5.xz/ }

// combine the two fast5 channels
fast5_all = fast5_loaded.concat(fast5_watcher)

// retrieve both file name and barcode path
fast5_split = fast5_all.map { file -> tuple(file.getSimpleName(), file.getParent(), file)}

process basecall {

    input:
    set name, parent, file from fast5_split

    // Does not execute for the end signal
    when:
    !(name ==~ /end-signal/)
    
    script:
    sv_fld = file("$parent".replace(/input/, "basecalled"))
    """
    mkdir -p ${sv_fld}
    xz -dk "${parent}/${name}.fast5.xz"
    echo "${parent}/${name}.fast5" | \
        /home/marco/ownCloud/neherlab/code/genome-assembly/ont-guppy-cpu/bin/guppy_basecaller \
        --compress_fastq \
        -s ${sv_fld} \
        --flowcell FLO-MIN106 --kit SQK-LSK109
    rm "${parent}/${name}.fast5"
    """
}