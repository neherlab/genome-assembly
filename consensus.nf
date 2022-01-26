// ------- Parameters definition -------

// 
params.run = "test"

// directory containing the basecalled reads
params.input_dir = file("runs/${params.run}/clustering")

// number of threads for the jobs
params.n_threads = 16


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


// ------- workflow -------

process msa {

    input:
        tuple val(bc), file(reads), file(cl_dir) from cluster_ch

    output:
        tuple val(bc), file(reads), file(cl_dir) into msa_out_ch

    script:
        """
        trycycler msa --cluster_dir $cl_dir
        """
}

msa_out_ch.view()

process partition {

    input:
        tuple val(bc), file(reads), file(cl_dir) from msa_out_ch

    output:
        tuple val(bc), file(cl_dir) into partition_out_ch

    script:
        """
        trycycler partition --reads $reads --cluster_dirs $cl_dir
        """
}

process consensus {

    input:
        tuple val(bc), file(cl_dir) from partition_out_ch

    output:
        tuple val(bc), file(cl_dir) into consensus_out_ch

    script:
        """
        trycycler consensus --cluster_dir $cl_dir
        """

}