task align_markdup_sort_index {
  String bwa
  String bwaopts
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
  Boolean markdups
  String tmp_dir

  String sb_options = if markdups then "--addMateTags" else "--addMateTags -a"

  command <<<
    set -e 

    mkdir -p ${tmp_dir}
    mkdir -p ${out_dir}

    ${bwa} mem -t ${threads} ${bwaopts} -R "${readgroup}" \
      -K 100000000 ${reference} ${fq} ${mq} \
    | ${samblaster} ${sb_options} \
      -d ${tmp_dir}/${outprefix}.discordant.sam \
      -s ${tmp_dir}/${outprefix}.splitters.sam \
      -u ${out_dir}/${outprefix}.unmapped.fq -e \
    | ${sambamba} view -f bam -S \
      -o ${tmp_dir}/${outprefix}.ns.alignment.bam -t ${threads} \
      /dev/stdin
    echo "alignment finished"

    # sort the alignments 
    ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} \
      -t ${threads} \
      -o ${out_dir}/${outprefix}.alignment.bam \
      ${tmp_dir}/${outprefix}.ns.alignment.bam
    echo "mapped: coord sort finished"

    # index the alignments
    ${sambamba} index -t ${threads} \
      ${out_dir}/${outprefix}.alignment.bam
    echo "mapped: index finished"

    # convert the discordant sam file to BAM
    ${sambamba} view -f bam -S -t ${threads} ${tmp_dir}/${outprefix}.discordant.sam \
    | ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} -t ${threads} \
      -o ${out_dir}/${outprefix}.discordant.bam /dev/stdin
    echo "discordant: coord sort finished"

    ${sambamba} index -t ${threads} ${out_dir}/${outprefix}.discordant.bam
    echo "discordant: index finished"  

    # convert the splitters sam file to BAM
    ${sambamba} view -f bam -S -t ${threads} ${tmp_dir}/${outprefix}.splitters.sam \
    | ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} -t ${threads} \
      -o ${out_dir}/${outprefix}.splitters.bam /dev/stdin
    echo "splitters: coord sort finished"

    ${sambamba} index -t ${threads} ${out_dir}/${outprefix}.splitters.bam
    echo "splitters: index finished"  

    # zip the unmapped fastq file 
    gzip ${out_dir}/${outprefix}.unmapped.fq 

    # delete the temp directory
    rm ${tmp_dir}/${outprefix}.discordant.sam
    rm ${tmp_dir}/${outprefix}.splitters.sam
    rm ${tmp_dir}/${outprefix}.ns.alignment.bam
  >>>

  runtime {
    cpus: threads
    requested_mem_per_cpu: 6000
  }

  output {
    File alignments = "${out_dir}/${outprefix}.alignment.bam"
    File alignments_index = "${out_dir}/${outprefix}.alignment.bam.bai"
    File discordants = "${out_dir}/${outprefix}.discordant.bam"
    File discordants_index = "${out_dir}/${outprefix}.discordant.bam.bai"
    File splitters = "${out_dir}/${outprefix}.splitters.bam"
    File splitters_index = "${out_dir}/${outprefix}.splitters.bam.bai"
    File unmapped = "${out_dir}/${outprefix}.unmapped.fq.gz"
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

  String? mq
  String mate_fq = select_first([mq, ""])

  String? bwa_options
  String bwaopts = select_first([bwa_options, "-Y"])

  Int? mem_sambamba
  Int memsambamba = select_first([mem_sambamba, 6])
  
  String? out_prefix
  String outprefix = select_first([out_prefix, sample])

  String? read_group
  String rg = "@RG\\tID:" + sample + "_" + lib + "_" + lane + "\\tSM:" + sample + "\\tPU:" + lane + "\\tPL:" + platform
  String readgroup = select_first([read_group, rg])

  Int? num_threads
  Int threads = select_first([num_threads, 1])

  Boolean? mark_dups
  Boolean markdups = select_first([mark_dups, true])

  call align_markdup_sort_index {
    input:
      bwa = bwa,
      bwaopts = bwaopts,
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
      markdups = markdups,
      tmp_dir = tmp_dir
  }

  output {
    File alignments = align_markdup_sort_index.alignments
    File alignments_index = align_markdup_sort_index.alignments_index
    File discordants = align_markdup_sort_index.discordants
    File discordants_index = align_markdup_sort_index.discordants_index
    File splitters = align_markdup_sort_index.splitters
    File splitters_index = align_markdup_sort_index.splitters_index
    File unmapped = align_markdup_sort_index.unmapped
  }
}
