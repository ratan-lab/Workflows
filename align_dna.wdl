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
  String tmp_dir

  command <<<
    set -e 

    mkdir -p ${tmp_dir}
    mkdir -p ${out_dir}

    ${bwa} mem -t ${threads} ${bwaopts} -R "${readgroup}" \
      -K 100000000 ${reference} ${fq} ${mq} \
    | ${samblaster} --addMateTags \
      -d ${tmp_dir}/${outprefix}.discordant.sam \
      -s ${tmp_dir}/${outprefix}.splitters.sam \
      -u ${out_dir}/${outprefix}.unmapped.fq -e \
    | ${sambamba} view -f bam -S \
      -o ${tmp_dir}/${outprefix}.ns.alignment.bam -t ${threads} \
      /dev/stdin
    echo "alignment finished"

    ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} \
      -t ${threads} \
      -o ${out_dir}/${outprefix}.alignment.bam \
      ${tmp_dir}/${outprefix}.ns.alignment.bam
    echo "mapped: coord sort finished"

    ${sambamba} index -t ${threads} \
      ${out_dir}/${outprefix}.alignment.bam
    echo "mapped: index finished"
  >>>

  output {
    File alignments = "${out_dir}/${outprefix}.alignment.bam"
    File alignments_index = "${out_dir}/${outprefix}.alignment.bam.bai"
    File discordants = "${tmp_dir}/${outprefix}.discordant.sam"
    File splitters = "${tmp_dir}/${outprefix}.splitters.sam"
    File unmapped = "${out_dir}/${outprefix}.unmapped.fq"
  }
}

task align_sort_index {
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
  String samtools
  Int threads
  String tmp_dir

  command <<<
    set -e 

    mkdir -p ${tmp_dir}
    mkdir -p ${out_dir}

    ${bwa} mem -t ${threads} ${bwaopts} -R "${readgroup}" \
       -K 100000000 ${reference} ${fq} ${mq} \
    | ${sambamba} view -f bam -S \
      -o ${tmp_dir}/${outprefix}.ns.alignment.bam -t ${threads} \
      /dev/stdin
    echo "alignment finished"

    ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} \
      -t ${threads} \
      -o ${out_dir}/${outprefix}.alignment.bam \
      ${tmp_dir}/${outprefix}.ns.alignment.bam
    echo "mapped: coord sort finished"

    ${sambamba} index -t ${threads} \
      ${out_dir}/${outprefix}.alignment.bam
    echo "mapped: index finished"
  >>>

  output {
    File alignments = "${out_dir}/${outprefix}.alignment.bam"
    File alignments_index = "${out_dir}/${outprefix}.alignment.bam.bai"
  }
}

task sam_to_bam {
  String sambamba
  Int threads
  String sam_file
  Int memsambamba
  String tmp_dir
  String out_name

  command <<<
    set -e 

    ${sambamba} view -f bam -S -t ${threads} ${sam_file} \
    | ${sambamba} sort -m ${memsambamba}G --tmpdir=${tmp_dir} -t ${threads} \
      -o ${out_name} /dev/stdin
    echo "coord sort finished"

    ${sambamba} index -t ${threads} ${out_name}
    echo "index finished"  
  >>>

  output {
    File bamfile = "${out_name}"
    File bamindex = "${out_name}" + ".bai"
  }
}

task zip_em {
  String infile

  command {
    gzip ${infile}
  }
  output {
    File outfile = "${infile}" + ".gz"
  }
}

task Xclean1 {
  File input1
  File input2
  File input3
  File input4
  File input5
  String tmp_dir

  command {
    rm -rf ${tmp_dir}
  }
}

task Xclean2 {
  File input1
  File input2
  String tmp_dir
  
  command {
    rm -rf ${tmp_dir}
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
  String out_dir  
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

  if (markdups) {
    call align_markdup_sort_index {
      input:
        bwa = bwa,
        bwaopts = bwaopts,
        fq = fq,
        mq = mate_fq,
        memsambamba = memsambamba,
        out_dir = out_dir,
        outprefix = outprefix,
        readgroup = readgroup,
        reference = reference,
        sambamba = sambamba,
        samblaster = samblaster,
        samtools = samtools,
        threads = threads,
        tmp_dir = tmp_dir
    }
    
    call sam_to_bam as for_discordants {
      input:
        sam_file = align_markdup_sort_index.discordants,
        sambamba = sambamba,
        threads = threads,
        memsambamba = memsambamba,
        tmp_dir = tmp_dir,
        out_name = out_dir + "/" + outprefix + ".discordant.bam"
    }

    call sam_to_bam as for_splitters {
      input:
        sam_file = align_markdup_sort_index.splitters,
        sambamba = sambamba,
        threads = threads,
        memsambamba = memsambamba,
        tmp_dir = tmp_dir,
        out_name = "${out_dir}/"+"${outprefix}"+".splitters.bam"
    }
    
    call zip_em { input: infile = align_markdup_sort_index.unmapped }

    call Xclean1 {
      input: 
        input1 = for_discordants.bamfile,
        input2 = for_discordants.bamindex,
        input3 = for_splitters.bamfile,
        input4 = for_splitters.bamindex,
        input5 = zip_em.outfile,
        tmp_dir = tmp_dir
    }
  }

  if (!markdups) {
    call align_sort_index {
      input:
        bwa = bwa,
        bwaopts = bwaopts,
        fq = fq,
        mq = mate_fq,
        memsambamba = memsambamba,
        out_dir = out_dir,
        outprefix = outprefix,
        readgroup = readgroup,
        reference = reference,
        sambamba = sambamba,
        samtools = samtools,
        threads = threads,
        tmp_dir = tmp_dir
    }

    call Xclean2 {
      input:
        input1 = align_sort_index.alignments,
        input2 = align_sort_index.alignments_index,
        tmp_dir = tmp_dir
    }
  }
}
