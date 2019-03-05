import "align_rna_sample.wdl" as sl

workflow AlignSamples {
  File inputs
  String star
  String reference
  String sambamba
  String final_out_dir
  Int threads
  String featurecounts
  File gtffile

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

  call quantify_genes {
    input:
      inputdir = final_out_dir,
      featurecounts = featurecounts,
      threads = threads,
      gtffile = gtffile
  }
}

task quantify_genes {
  String inputdir
  String featurecounts
  File gtffile
  Int threads

  command {
    ${featurecounts} -a ${gtffile} -o ${inputdir}/counts.txt -p -T ${threads}  -t exon -g gene_id ${inputdir}/*.bam
  }

  output {
    File countfile = "${inputdir}/counts.txt"
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
