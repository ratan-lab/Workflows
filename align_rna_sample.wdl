workflow align_rna {
  String star
  String reference
  String sample
  String read_group
  String fq
  String mq

  String sambamba
 
  String out_dir
  Int threads

  call align_rna_files {
    input:
      out_dir = out_dir,
      star = star,
      reference = reference,
      threads = threads,
      sample = sample,
      read_group = read_group,
      fq = fq,
      mq = mq,
      sambamba = sambamba
  }

  output {
    File alignments = align_rna_files.alignments
    File logfile = align_rna_files.logfile
  }
}

task align_rna_files {
  String star
  String reference
  String sample
  String read_group
  String fq
  String mq
  String sambamba
  String out_dir
  Int threads

  command <<<
    mkdir ${out_dir}
    ${star} --genomeDir ${reference} --runThreadN ${threads} \
      --outSAMstrandField intronMotif --outFileNamePrefix ${out_dir}/${sample}. \
      --outSAMattrRGline ${read_group} --readFilesIn ${fq} ${mq} \
      --readFilesCommand zcat

    ${sambamba} view -f bam -S -o ${out_dir}/${sample}.ns.bam \
      -t ${threads} ${out_dir}/${sample}.Aligned.out.sam 
  >>>

  output {
    File alignments = "${out_dir}/${sample}.ns.bam"
    File logfile = "${out_dir}/${sample}.Log.final.out"
  }
}
