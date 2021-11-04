#!/usr/bin/env nextflow

// run for which the pipeline should be executed
params.run = 'test'

// channel for already loaded fast5 files
fast5_loaded = Channel.fromPath("runs/${params.run}/input/barcode*/*fast5.xz")
// watcher channel for incoming fast5. Terminates when 'end-signal.fast5.xz' file is loaded
fast5_watcher = Channel.watchPath("runs/${params.run}/input/barcode*/*.fast5.xz")
                        .until { it.name ==~ /end-signal.fast5.xz/ }

// fast5_loaded.subscribe { println "loaded fast5 : $it" }
// fast5_watcher.subscribe { println "watcher fast5 : $it" }

// combine the two fast5 channels
fast5_all = fast5_loaded.concat(fast5_watcher)

// fast5_all.subscribe { println "all fast5 : $it.name" }

process basecall {

    // TODO: the publishDir directive might be used to save the files? 
    // https://www.nextflow.io/docs/latest/process.html#publishdir

    input:
    path x from fast5_all

    // Does not execute for the end signal
    when:
    !(x.name ==~ /end-signal.fast5.xz/)
    
    script:
    """
    echo $x.name
    """
}