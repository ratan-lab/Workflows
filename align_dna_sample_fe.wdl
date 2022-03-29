task align_markdup_sort_index {
  String bwa
  String fq
  String mq
  String out_dir
  Int memsambamba
  String outprefix
  String readgroup
  String reference
  String sambamba
  String samblaster
  String samtools
  Int threads
  String tmp_dir
  String picardjar
  String gatk
  String dbnsp
  String mills
  String indels

  command <<<
    set -e 

    mkdir -p ${tmp_dir}
    mkdir -p ${out_dir}

    # align the reads
    ${bwa} mem -t ${threads} -K 100000000 -Y -R "${readgroup}" \
      ${reference} ${fq} ${mq} \
    | ${samblaster} -a --addMateTags \
    | ${sambamba} view -f bam -S \
      -o ${tmp_dir}/${outprefix}.ns.alignment.bam -t ${threads} \
      /dev/stdin
    echo "alignment finished"

    # mark the duplicates
    java -Xmx ${memsamba}G -jar ${picardjar} MarkDuplicates \
      --INPUT=${tmp_dir}/${outprefix}.ns.alignment.bam \
      --METRICS_FILE=${out_dir}/${outprefix}.dups.txt \
      --OUTPUT=${tmp_dir}/${outprefix}.ns.dedup.alignment.bam \
      --ASSUME_SORT_ORDER=queryname \
      --MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
      --REFERENCE_SEQUENCE=${reference} \
      --TMP_DIR=${tmp_dir} \
      --VALIDATION_STRINGENCY=LENIENT 

    # sort the alignments 
    ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} \
      -t ${threads} \
      -o ${tmp_dir}/${outprefix}.dedup.alignment.bam \
      ${tmp_dir}/${outprefix}.ns.dedup.alignment.bam
    echo "mapped: coord sort finished"

    # index the alignments
    ${sambamba} index -t ${threads} \
      ${tmp_dir}/${outprefix}.dedup.alignment.bam
    echo "mapped: index finished"

    # base quality score recalibration
    ${gatk} BaseRecalibrator \
      -R ${reference} \
      -I ${tmp_dir}/${outprefix}.dedup.alignment.bam \
      -O ${tmp_dir}/${outprefix}.recalib.txt \
      --known-sites ${dbnsp} \
      --known-sites ${mills} \
      --known-sites ${indels} 

    ${gatk} ApplyBQSR \
      -R ${reference} \
      -I ${tmp_dir}/${outprefix}.dedup.alignment.bam \
      -O ${tmp_dir}/${outprefix}.dedup.bqsr.alignment.bam \
      -bqsr ${tmp_dir}/${outprefix}.recalib.txt \
      -SQQ 10 -SQQ 20 -SQQ 30 \
      --preserve_qscores_less_than 6 \
      --disable_indel_quals 

    # convert to CRAM
    ${samtools} view -T ${reference} -C \
      -o ${out_dir}/${outprefix}.alignment.cram \
      ${tmp_dir}/${outprefix}.dedup.bqsr.alignment.bam 

    # delete the temp directory
    rm ${tmp_dir}/${outprefix}.ns.alignment.bam
    rm ${tmp_dir}/${outprefix}.ns.dedup.alignment.bam
    rm ${tmp_dir}/${outprefix}.dedup.bqsr.alignment.bam 
  >>>

  runtime {
    cpus: threads
    requested_mem_per_cpu: 6000
  }

  output {
    File alignments = "${out_dir}/${outprefix}.alignment.cram"
    File alignments_index = "${out_dir}/${outprefix}.alignment.cram.crai"
    File dup_metrics="${out_dir}/${outprefix}.dups.txt"
  }
}

workflow align_dna {
  # information from the samplesheet
  String sample
  String lib
  String? lane_num
  String lane = select_first([lane_num, "1"])
  String? platform_name
  String platform = select_first([platform_name, "illumina"])

  String bwa
  String fq 
  String reference   
  String sambamba
  String samblaster
  String samtools
  String tmp_dir
  String picardjar
  String gatk

  String? mq
  String mate_fq = select_first([mq, ""])

  Int? mem_sambamba
  Int memsambamba = select_first([mem_sambamba, 6])
  
  String? out_prefix
  String outprefix = select_first([out_prefix, sample])

  String? read_group
  String rg = "@RG\\tID:" + sample + "_" + lib + "_" + lane + "\\tSM:" + sample + "\\tPU:" + lane + "\\tPL:" + platform
  String readgroup = select_first([read_group, rg])

  Int? num_threads
  Int threads = select_first([num_threads, 1])

  call align_markdup_sort_index {
    input:
      bwa = bwa,
      fq = fq,
      mq = mate_fq,
      memsambamba = memsambamba,
      out_dir = sample,
      outprefix = outprefix,
      readgroup = readgroup,
      reference = reference,
      sambamba = sambamba,
      samblaster = samblaster,
      samtools = samtools,
      threads = threads,
      tmp_dir = tmp_dir,
      gatk = gatk,
      picardjar = picardjar
  }

  output {
    File alignments = align_markdup_sort_index.alignments
    File alignments_index = align_markdup_sort_index.alignments_index
    File dup_metrics = align_markdup_sort_index.dup_metrics
  }
}
