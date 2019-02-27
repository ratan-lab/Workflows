import "align_rna_sample.wdl" as sl

workflow AlignSamples {
  File inputs
  String star
  String reference
  String sambamba
  String final_out_dir
  Int threads

  Array[Array[File]] samples = read_tsv(inputs)

  scatter (sample in samples) {
    call sl.align_rna {
      input:
        star = star,
        sambamba = sambamba,
        threads = threads,
        reference = reference,
        sample = sample[0],
        fq = sample[1],
        mq = sample[2],
        read_group = sample[3],
        out_dir = sample[0]
    }

    call copy {
      input:
        files = [align_rna.alignments, align_rna.logfile],
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
