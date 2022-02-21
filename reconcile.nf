
// 
params.run = "test"

// directory containing the basecalled reads
params.input_dir = file("runs/${params.run}/clustering")

// ------- capture and setup input -------

// capture barcode folders
barcodes_ch = Channel.fromPath("${params.input_dir}/barcode*", type: 'dir')


// separate into barcode label, filtlong reads and cluster folder
cluster_ch = barcodes_ch
    .map { [
        it.getSimpleName(), 
        file("$it/filtlong_reads.fastq", type: 'dir'),
        file("$it/cluster_*", type: 'dir')
           ]}
    .transpose()
    .map {[ 
        it[0],
        it[2].getSimpleName(),
        it[1],
        file("${it[2]}/*_contigs", type: 'dir')
        ]}

// ------- workflow -------

// PROCESS -> reconcile
// - performs trycycle reconcile
// - produces and stores a reconcile_log.txt file, which contains the output of reconcile command.
//   This can be used to take decisions on which contigs to remove.
// - if reconcile is successful, saves the 2_all_seqs.fasta file
// - produces a summary_log.txt file. All of these files are later concatenated and saved
//   in the main directory, to have a summary of which contigs failed to reconcile.
process reconcile {

    label 'q30m_highmem'

    publishDir "$params.input_dir/$bc/$cl",
        mode: 'copy',
        pattern: '{reconcile_log.txt,2_all_seqs.fasta}'

    input:
        tuple val(bc), val(cl), file(reads), file(cl_dirs) from cluster_ch

    output:
        path("reconcile_log.txt")
        path("2_all_seqs.fasta") optional true
        path("summary_log.txt") into summary_ch


    script:
        """
        # prepare cluster directory, put contigs inside
        mkdir $cl
        mv *_contigs $cl

        # run trycycle reconcile. Save stout and stderr to file. Escape possible errors
        trycycler reconcile --reads $reads --cluster_dir $cl > reconcile_log.txt 2>&1 \
        || echo process failed >> reconcile_log.txt

        # append to file the tag of barcode and cluster
        echo $bc $cl >> reconcile_log.txt

        # write on file whether reconcile was successful. If so, move generated file
        # to main directory for capture
        if [ -f $cl/2_all_seqs.fasta ]; then
            echo reconcile success >> reconcile_log.txt
            mv $cl/2_all_seqs.fasta 2_all_seqs.fasta
        else
            echo reconcile failure >> reconcile_log.txt
        fi

        # save only success state to summary_log.txt file
        tail -n 2 reconcile_log.txt > summary_log.txt
        """
}

// concatenate summary files and save in the input directory as reconcile_summary.txt
summary_ch.collectFile(name: 'reconcile_summary.txt', storeDir: params.input_dir, newLine: true)
