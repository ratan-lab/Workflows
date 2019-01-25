import "align_dna_sample.wdl" as sl

workflow AlignSamples {
  File inputs

  String bwa
  String reference   
  String sambamba
  String samblaster
  String samtools
  String tmp_dir
  String final_out_dir

  String? bwa_options
  String bwaopts = select_first([bwa_options, "-Y"])

  Int? mem_sambamba
  Int memsambamba = select_first([mem_sambamba, 6])
  
  Int? num_threads
  Int threads = select_first([num_threads, 1])

  Boolean? mark_dups
  Boolean markdups = select_first([mark_dups, true])

  Array[Array[File]] samples = read_tsv(inputs)  

  scatter (sample in samples) {
    call sl.align_dna {
      input:
        sample = sample[0],
        lib = sample[1],
        lane_num = sample[2],
        fq = sample[3],
        mq = sample[4],
        bwa = bwa,
        reference = reference,
        sambamba = sambamba,
        samblaster = samblaster,
        samtools = samtools,
        tmp_dir = tmp_dir,
        bwa_options = bwaopts,
        mem_sambamba = memsambamba,
        num_threads = threads,
        mark_dups = markdups,
    }

    call copy {
      input:
        files = [align_dna.alignments, align_dna.alignments_index,
                 align_dna.discordants, align_dna.discordants_index,
                 align_dna.splitters, align_dna.splitters_index,
                 align_dna.unmapped],
        destination = final_out_dir
    }
  }
}

task copy {
  Array[File] files
  String destination

  command {
    mkdir -p ${destination}
    cp -L -R -u ${sep=' ' files} ${destination}
  }

  output {
    Array[File] out = files
  }
}
