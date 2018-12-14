workflow run_fastqc {
  Array[String] fastq_files
  Boolean multiple_files = length(fastq_files) > 1
  String out_dir

  String fastqc
  String java
  String multiqc

  Int? num_threads
  Int threads = select_first([num_threads, 1])

  Int? num_kmers
  Int kmers = select_first([num_kmers, 7])

  String? contaminants_file
  String contaminants = select_first([contaminants_file, ""])

  String? adapters_file
  String adapters = select_first([adapters_file, ""])

  # create output directory if needed
  call create_dir {
    input:
      dir = out_dir
  }

  call run_fastqc {
    input:
      fastqc = fastqc,
      fastq_files = fastq_files,
      java = java,
      out_dir = out_dir,
      threads = threads,
      kmers = kmers,
      contaminants = contaminants,
      adapters = adapters
  }

  # if more than one fastq file, run multiqc
  if (multiple_files){
    call run_multiqc {
      input:
        dir = out_dir,
        multiqc = multiqc
    }
  }
}

task create_dir {
  String dir
  command {
    mkdir -p ${dir}
  }
}

task run_fastqc {
    String fastqc
    Array[String] fastq_files
    String java
    String out_dir
    Int threads
    Int kmers
    String contaminants
    String adapters

    String additional_options = if contaminants then "-c " + contaminants else "" + if adapters then "-a " + adapters else ""

    command {
      ${fastqc} -o ${out_dir} -j ${java} -t ${threads} -k ${kmers} ${additional_options}
    }
    output {
      #TODO check if contaminants and adapters generate additional files
      #TODO scatter if there is no better option
    }
}

task run_multiqc {
  String dir
  String multiqc

  command {
    ${multiqc} -o ${dir} ${dir}
  }
  output {
    #TODO
  }
}
