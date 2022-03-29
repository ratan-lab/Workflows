This recipe is based on the functional equivalence pipeline (https://www.nature.com/articles/s41467-018-06159-4). It should be used to align Illumina short reads from DNA sequencing experiments (WGS, Amplicon sequencing, Exome-capture,...) to the human reference genome (hg38).

Required Tools:
* BWA (v 0.7.15)
* SAMBlaster 
* Picard (v2.4.1 or above)
* SamBamba
* Samtools
* GATK 

Required files:
* a TSV file with 
  * sample
  * library name
  * lane 
  * Fastq file (optionally zipped) of read1s
  * Fastq file of read2s in the case of paired-end files
* GRCh38DH, [1000 Genomes Project version](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/)
  * Includes the standard set of chromosomes and alternate sequences from GRCh38
  * Includes the decoy sequences
  * Includes additional alternate versions of the HLA locus (alt file is supplied but the alignments are not post-processed)
* More details here: https://github.com/CCDG/Pipeline-Standardization/blob/master/PipelineStandard.md#reference-genome-version

Notes:
* The read group for the BAM is created using the following expression
  rg = "@RG\\tID:" + sample + "_" + lib + "_" + "\\tLB" + lib + lane + "\\tSM:" + sample + "\\tPU:" + lane + "\\tPL:" + platform
