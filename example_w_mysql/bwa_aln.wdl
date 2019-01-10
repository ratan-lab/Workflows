# wdl workflow 
# bwa aln

workflow bwa_mem {

	String sample_name 

	call align {
		input:
			sample_name = sample_name
	}


	call sortSam {
		input:
			sample_name = sample_name,
			insam = align.outsam
	}
}


### Task definitions 

task align {
	String sample_name
	File r1fastq
	File r2fastq
	File ref_fasta
	File ref_fasta_amb
	File ref_fasta_sa
	File ref_fasta_bwt
	File ref_fasta_ann
	File ref_fasta_pac
	Int threads

	command {
		bwa mem -M -t ${threads} ${ref_fasta} ${r1fastq} ${r2fastq} > ${sample_name}.hg38-bwamem.sam
	}

	runtime {
		cpu : threads
		requested_memory_mb : 16000
	}

	output {
		File outsam = "${sample_name}.hg38-bwamem.sam"
	}
}


task sortSam {
	String sample_name
	File insam

	command <<<
		java -jar $EBROOTPICARD/picard.jar \
			SortSam \
			I=${insam} \
			O=${sample_name}.hg38-bwamem.sorted.bam \
			SORT_ORDER=coordinate \
			CREATE_INDEX=true
	>>>

	output {
		File outbam = "${sample_name}.hg38-bwamem.sorted.bam"
		File outbamidx = "${sample_name}.hg38-bwamem.sorted.bai"
	}
}
