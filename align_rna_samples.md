This recipe should be used to align Illumina short reads from RNA sequencing experiments to a reference genome in FASTA format. We use 'STAR' to generate sorted alignments. After then we use FeatureCounts to count the number of reads assigned to genes.

Required Tools
* STAR
* Sambamba
* FeatureCounts

Required files
* index files using STAR
* A GTF file of annotations/features
* a TSV file with
  * sample name
  * Fastq file of read1s
  * Fastq file of read2s
  * read group for this sample
