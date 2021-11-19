
params.run = "test"
params.input_dir = file("runs/${params.run}/basecalled")

fastq_input_ch = Channel.fromPath("${params.input_dir}/barcode*.fastq.gz")

process filtlong {

    label 'q30m'

    input:
        path fastq_file from fastq_input_ch


    output:
        tuple val("${fastq_file.getSimpleName()}"), file ("reads.fastq") into fastq_filtered_ch

    script:
        """
        filtlong --min_length 1000 --keep_percent 95 $fastq_file > reads.fastq
        """
}


process subsampler {

    label 'q30m'

    input:
        tuple val (bc), file ("reads.fastq") from fastq_filtered_ch


    output:
        file("${bc}/sample_*.fastq") into subsampled_ch

    script:
        """
        trycycler subsample --reads reads.fastq --out_dir ${bc}
        """
}

subsampled_ch.view { $it }



