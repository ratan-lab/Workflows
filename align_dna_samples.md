This recipe should be used to align Illumina short reads from DNA sequencing experiments (WGS, Amplicon sequencing, Exome-capture,...) to a reference genome in FASTA format. We use 'BWA mem' to generate sorted alignments. The discordant pairs, split reads and the unmapped sequences are also generated as output. By default the putative PCR duplicates are flagged as well. 

Required Tools:
* BWA
* SAMBlaster
* SamBamba
* Samtools

Required files:
* files from running 'BWA index' on the reference genome
* a TSV file with 
  * sample
  * library name
  * lane 
  * Fastq file (optionally zipped) of read1s
  * Fastq file of read2s in the case of paired-end files

Notes:
* The read group for the BAM is created using the following expression
  rg = "@RG\\tID:" + sample + "_" + lib + "_" + lane + "\\tSM:" + sample + "\\tPU:" + lane + "\\tPL:" + platform
