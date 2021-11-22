// ------- Parameters definition -------

// 
params.run = "test"

// directory containing the basecalled reads
params.input_dir = file("runs/${params.run}/basecalled")

// number of threads for the jobs
params.n_threads = 16

// output directory in which trycycler clusters are saved for further inspection
params.trycyler_dir = file("runs/${params.run}/clustering")

// location of miniasm_and_minipolish script
params.miniasm_script = file("$baseDir/scripts/miniasm_and_minipolish.sh")

// ------- workflow -------

// channel containing input reads
fastq_input_ch = Channel.fromPath("${params.input_dir}/barcode*.fastq.gz")

// pre-filtering step with fitlong
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

// send two copies of the output in two channels
// one will be used for assembly
// the other for clustering after assembly (trycycler cluster)
fastq_filtered_ch.into { to_subsampler ; to_clustering }

// subsamble the reads in 12 samples
process subsampler {

    label 'q30m'

    errorStrategy 'ignore'

    input:
        tuple val (bc), file ("reads.fastq") from to_subsampler


    output:
        tuple val(bc), file("${bc}/sample_*.fastq") optional true into subsampled_ch

    script:
        """
        trycycler subsample \
            --reads reads.fastq \
            --out_dir ${bc} \
            # --min_read_depth 1
        """
}

// turn the output pipe, in which items are in format [barcode, [samples...]] 
// into single items in the format [barcode, sample number, file].
// these samples are then sent into the three different subchannels destined
// to different assemblers (flye, raven, minipolish)
toassemble_ch = subsampled_ch
          .transpose() // assign barcode to each file
          .map { 
            it -> [it[0],
                   it[1].getSimpleName().find(/(?<=^sample_)\d+$/).toInteger(),
                   it[1]]
          }
          .branch { // split into different subchannels
            flye : it[1] <= 4
            raven : it[1] >= 9
            mini : true 
          }

// assemble with flye
process assemble_flye {

    label 'q30m'

    input:
        tuple val(barcode), val(sample_num), file(fq) from toassemble_ch.flye

    output:
        tuple val(barcode), file("assembly/assembly.fasta") into flye_out

    script:
        """
        flye --nano-raw $fq \
            --threads $params.n_threads \
            --out-dir assembly
        """
}

// assemble with raven
process assemble_raven {

    label 'q30m'

    input:
        tuple val(barcode), val(sample_num), file(fq) from toassemble_ch.raven

    output:
        tuple val(barcode), file("assembly.fasta") into raven_out

    script:
        """
        raven --threads $params.n_threads \
            $fq > assembly.fasta
        rm raven.cereal
        """
}

// assemble with minipolish
process assemble_mini {

    label 'q30m'

    input:
        tuple val(barcode), val(sample_num), file(fq) from toassemble_ch.mini

    output:
        tuple val(barcode), file("assembly.fasta") into mini_out

    script:
        """
        bash ${params.miniasm_script} \
            $fq $params.n_threads > assembly.gfa \
        && any2fasta assembly.gfa > assembly.fasta \
        && rm assembly.gfa
        """
}

// collect all the assembled files. Items are collected in format
// [barcode, assembly.fasta] and are grouped by barcodes in chunks of size 12
// [barcode, [assembly_01.fasta ... assembly_12.fasta]] to be sent to
// trycycler cluster
assembled_ch = flye_out.mix(raven_out, mini_out).groupTuple(size: 12).join(to_clustering)

// trycicler cluster. Takes as input the assembly files for each barcode, along with the
// fastq reads. Resulting clusters are saved in the `clustering/barcodeXX` folder
// for further inspection.
process trycycler_cluster {

    label 'q30m'

    publishDir params.trycyler_dir, mode: 'move'

    input:
        tuple val(barcode), file("assemblies_*.fasta"), file("reads.fastq") from assembled_ch

    output:
        file("$barcode")

    script:
        """
        trycycler cluster \
            --reads reads.fastq \
            --assemblies assemblies_*.fasta \
            --out_dir $barcode
        """
}
