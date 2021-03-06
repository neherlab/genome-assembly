# First create a folder for the specific barcode, choose a name
# Unzip the files
# 1. Combine all raw fastq.gz files from the nanopore into one.

gzip -cdk FAL*gz | gzip -c > compressed_FAL02202.fastq.gz

# This takes a while
# Then activate the conda environment

conda activate trycycler

# 2. First make some light quality control, throws out all very bad reads below 1kbp (If the read depth is high enough one can throw out more aggressively, but at the risk of compromising really small plasmids)

filtlong --min_length 1000 --keep_percent 95 compressed_FAL02202.fastq.gz > reads.fastq

# 3. Then run the subsample command on the reads.fastq file.

trycycler subsample --reads reads.fastq --out_dir read_subsets

# Shows if read depth is sufficient: Below 50x is bad, over 100x is good, from there the higher the better

# Subsampling: Turns a single long read set into multiple subsets that can be used to generate input assemblies for the Trycycler.
# Randomly shuffels reads to protect against temporal effects, e.g. that latter reads suffer in quality during Oxford Nanopore.
# Determines subset depth: (Default is lower bound is 25x, but can be changed with min_read_depth number)
# The more read depth the easier the assembly, but this lessens the read independence.
# https://github.com/rrwick/Trycycler/wiki/How-read-subsampling-works Explains how it works exactly

# 4. To make the initial assemblies, use different assemblers to avoid individual errors. Using different assemblers cancels out individual errors.
# Makes different assemblies of the same genome
# Use the 12 read sets generated in the last step (If time is short, use less but this might reduce quality)
# The assemblers take individual reads and spit out continuous sequences (contigs)
# Here we use rave, flye, miniasm+minipolish as assemblers
# sequence assembly refers to aligning and merging fragments from a longer DNA sequence in order to reconstruct the original sequence

# Look at how many threads you have with $ lscpu | grep -E '^Thread|^Core|^Socket|^CPU\('

threads=16 # Add thread count approporiate for the system one is using.
mkdir assemblies # Create folder where assemblies will be saved

# (flye: need to look into: WARNING: --plasmids mode is no longer available. Command line option will be removed in the future versions)

flye --nano-raw read_subsets/sample_01.fastq --threads "$threads" --plasmids --out-dir assembly_01 && cp assembly_01/assembly.fasta assemblies/assembly_01.fasta && rm -r assembly_01
~/2021_project_folder/2021_trycycler_assembly/Minipolish/miniasm_and_minipolish.sh read_subsets/sample_02.fastq "$threads" > assembly_02.gfa && any2fasta assembly_02.gfa > assemblies/assembly_02.fasta && rm assembly_02.gfa
raven --threads "$threads" read_subsets/sample_03.fastq > assemblies/assembly_03.fasta && rm raven.cereal

flye --nano-raw read_subsets/sample_04.fastq --threads "$threads" --plasmids --out-dir assembly_04 && cp assembly_04/assembly.fasta assemblies/assembly_04.fasta && rm -r assembly_04
~/2021_project_folder/2021_trycycler_assembly/Minipolish/miniasm_and_minipolish.sh read_subsets/sample_05.fastq "$threads" > assembly_05.gfa && any2fasta assembly_05.gfa > assemblies/assembly_05.fasta && rm assembly_05.gfa
raven --threads "$threads" read_subsets/sample_06.fastq > assemblies/assembly_06.fasta && rm raven.cereal

flye --nano-raw read_subsets/sample_07.fastq --threads "$threads" --plasmids --out-dir assembly_07 && cp assembly_07/assembly.fasta assemblies/assembly_07.fasta && rm -r assembly_07
~/2021_project_folder/2021_trycycler_assembly/Minipolish/miniasm_and_minipolish.sh read_subsets/sample_08.fastq "$threads" > assembly_08.gfa && any2fasta assembly_08.gfa > assemblies/assembly_08.fasta && rm assembly_08.gfa
raven --threads "$threads" read_subsets/sample_09.fastq > assemblies/assembly_09.fasta && rm raven.cereal

flye --nano-raw read_subsets/sample_10.fastq --threads "$threads" --plasmids --out-dir assembly_10 && cp assembly_10/assembly.fasta assemblies/assembly_10.fasta && rm -r assembly_10
~/2021_project_folder/2021_trycycler_assembly/Minipolish/miniasm_and_minipolish.sh read_subsets/sample_11.fastq "$threads" > assembly_11.gfa && any2fasta assembly_11.gfa > assemblies/assembly_11.fasta && rm assembly_11.gfa
raven --threads "$threads" read_subsets/sample_12.fastq > assemblies/assembly_12.fasta && rm raven.cereal

# Delete the read_subsets they wont be needed anymore

rm -r read_subsets

# (Optional step, not yet implemented, look at circularity of the assemblies using bandage, QC step)

# 5. Cluster the asseblies:
# Clusters the sequences into chromosomes and plasmids, the nearer on the tree the clusters are, the more k-mer counts they share
# Single clusters could that are near other clusters are most likely incomplete or errorous
# Clusters contigs, which are overlapping DNA-reads from the same source.

trycycler cluster --reads reads.fastq --assemblies assemblies/*.fasta --out_dir trycycler

# 6. Look at the cluster tree using Rskript

Rscript ~/2021_project_folder/2021_trycycler_assembly/phylogenetic_tree_script.R

# Then enter path to contigs.newick

# 7. Sort out bad clusters by renaming them

mv trycycler/cluster_003 trycycler/bad_cluster_003

# 8. Reconcile clusters
# Flips contigs which are pointing in the wrong direction, sequences are aligned to achive circularization, overlapping bases are trimmed, or missing ones added at the ends.
# Tries to make everything fit together
# Done for each cluster
# If any of the sequences have a pairwise global alignment percent identity of less than this (default = 98), then the contigs will fail the final check


trycycler reconcile --reads reads.fastq --cluster_dir trycycler/cluster_001

# Again remove bad contigs by renaming them

mv trycycler/cluster_001/1_contigs/F_utg000001c.fasta trycycler/cluster_001/1_contigs/F_utg000001c.fasta.bad

# Use dotplot to compare contigs visually:

trycycler dotplot --cluster_dir trycycler/cluster_002

# You should aim to have around four to eight contigs left after running Trycycler reconcile
# More than nine contigs are not adding much more additional value

# Multiple sequence alignments per cluster
# Should be hands of, takes a few minutes

trycycler msa --cluster_dir trycycler/cluster_001

# Partition the sequences for each cluster

trycycler partition --reads reads.fastq --cluster_dirs trycycler/cluster_001 trycycler/cluster_002 trycycler/cluster_003

# (The consensus step will take the msa and partition data and build a consensus sequence)

# Trycycler now builds a consensus sequence for each cluster:

trycycler consensus --cluster_dir trycycler/cluster_001

# Concatinate the final consensus sequences into one file

cat trycycler/cluster_*/7_final_consensus.fasta > assembly.fasta

# Polishing step with Medeka (For long reads) (conda install -c bioconda medaka)
# Requires python 3.6 to 3.7
# Unsure of wich model -m to use, used standard suggestion given by: medaka tools list\_models

for c in trycycler/cluster_*; do
    medaka_consensus -i "$c"/4_reads.fastq -d "$c"/7_final_consensus.fasta -o "$c"/medaka -m r941_min_high_g360 -t 12
    mv "$c"/medaka/consensus.fasta "$c"/8_medaka.fasta
    rm -r "$c"/medaka "$c"/*.fai "$c"/*.mmi  # clean up
done


# Same as above just for one cluster (VIP install medaka via pip install since the version on conda is not up to date)
medaka_consensus -i /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/4_reads.fastq -d /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/7_final_consensus.fasta -o /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/medaka -m r941_min_sup_g507 -t 16;
mv /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/medaka/consensus.fasta /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/8_medaka.fasta
rm -r /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/medaka /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/*.fai /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/*.mmi


# Prokka annotate genome:

prokka --outdir /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/mydir --prefix mygenome /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/8_medaka.fasta

# Visualize genome with artemis

art /home/reto/2021_project_folder/2021_trycycler_assembly/2021_11_23_Microbiome_Alex2/clustering/barcode01/cluster_001/mydir/mygenome.gff