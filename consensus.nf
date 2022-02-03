// ------- Parameters definition -------

// 
params.run = "test"

// directory containing the basecalled reads
params.input_dir = file("runs/${params.run}/clustering")


// ------- capture and setup input -------

// capture barcode folders
barcodes_ch = Channel.fromPath("${params.input_dir}/barcode*", type: 'dir')

// performs three different operations:
// - captures barcode, filtlong_reads.fastq and list of clusters.
// - transposes, to have one item per cluster with assigned barcode
// - captures the label of destination folder barcodeXX/cluster_XXX,
//     the filtlong_reads.fastq file and the 2_all_seqs.fasta file.
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

// create two channels with just label and 2_all_seqs.fasta
// for msa and consensus.
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

// duplicate for use in consensus and medaka
partition_out.into { partout_1; partout_2}

// combine three channels, for files 2,3,4
// to be used as input of consensus
consensus_in = pre_consensus.join(msa_out).join(partout_1)

// executes trycycler consensus and creates 7_final_consensus.fasta
process consensus {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "7_final_consensus.fasta"

    input:
        tuple val(code), "2_all_seqs.fasta", "3_msa.fasta", "4_reads.fastq" from consensus_in

    output:
        tuple val(code), file("7_final_consensus.fasta") into consensus_out

    script:
        """
        trycycler consensus --cluster_dir .
        """

}

// join 7_final_consensus and 4_reads in a single channel
medaka_in = partout_2.join(consensus_out)

// polish using medaka. Creates a 8_medaka.fasta file
process polish {

    label 'q30m'

    conda 'conda_envs/medaka_env.yml'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "8_medaka.fasta"

    input:
        tuple val(code), file(reads), file(consensus) from medaka_in

    output:
        tuple val(code), file("8_medaka.fasta") into medaka_out

    script:
        """
        medaka_consensus \
            -i 4_reads.fastq \
            -d 7_final_consensus.fasta \
            -o medaka \
            -m r941_min_high_g360 \
            -t 8
        mv medaka/consensus.fasta medaka_temp.fasta
        rm -r medaka
        echo ">${code}_consensus" > 8_medaka.fasta
        tail -n +2 medaka_temp.fasta >> 8_medaka.fasta
        """

}

// groups 8_medaka output files by barcode
concatenate_in = medaka_out.map{[
        "${it[0]}".split('/')[0],
        it[1]
    ]}
    .groupTuple()

// concatenates all medaka files with the same barcode
process concatenate {

    label 'q30m_1core'

    input:
        tuple val(bc), file("medaka_*.fasta") from concatenate_in

    output:
        tuple val(bc), file("medaka_consensus.fasta") into prokka_in

    script:
    """
    cat medaka_*.fasta > medaka_consensus.fasta
    """

}

// executes prokka on the set of all medaka consensus for one barcode.
process prokka {

    label 'q30m'

    conda 'conda_envs/prokka_env.yml'

    publishDir "$params.input_dir/$bc",
        mode : 'copy'

    input:
        tuple val(bc), file("medaka_consensus.fasta") from prokka_in

    output:
        path("prokka_$bc", type: 'dir')

    script:
    """
    prokka --outdir prokka_$bc --prefix ${bc}_genome --cpus 8 medaka_consensus.fasta
    """
}
