// ------- Parameters definition -------

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
        "${it[0]}/${it[2].getSimpleName()}", // which file
        it[1], // reads
        file("${it[2]}/2_all_seqs.fasta", type: 'file') // all seqs
        ]}
    .into { remove_reads; partition_in}

remove_reads
    .map { [it[0], it[2]] }
    .into { msa_in; pre_consensus}

// ------- workflow -------

process msa {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "3_msa.fasta"

    input:
        tuple val(code), "2_all_seqs.fasta" from msa_in

    output:
        tuple val(code), file("3_msa.fasta") into msa_out

    script:
        """
        trycycler msa --cluster_dir .
        """
}

process partition {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "4_reads.fastq"

    input:
        tuple val(code), file(reads), "2_all_seqs.fasta" from partition_in

    output:
        tuple val(code), file("4_reads.fastq") into partition_out

    script:
        """
        trycycler partition --reads $reads --cluster_dirs .
        """
}

// combine three channels, for files 2,3,4

consensus_input = pre_consensus.join(msa_out).join(partition_out)

process consensus {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "7_final_consensus.fasta"

    input:
        tuple val(code), "2_all_seqs.fasta", "3_msa.fasta", "4_reads.fastq" from consensus_input

    output:
        tuple val(code), file("7_final_consensus.fasta") into consensus_out

    script:
        """
        trycycler consensus --cluster_dir .
        """

}

// TODO: install medaka
// https://github.com/rrwick/Trycycler/wiki/Polishing-after-Trycycler
// process polish {

//     label 'q30m'

//     publishDir "$params.input_dir/$code",
//         mode : 'copy'

//     input:


//     output:
//         file("7_final_consensus.fasta")
//         file("8_medaka.fasta")

//     script:
//         """
//         medaka_consensus -i 4_reads.fastq -d 7_final_consensus.fasta -o medaka -m r941_min_sup_g507 -t 12
//         mv medaka/consensus.fasta 8_medaka.fasta
//         rm -r medaka *.fai *.mmi
//         """

// }