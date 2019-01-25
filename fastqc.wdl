workflow fastqc {
  Array[String] fastq_files
  String final_out_dir

  String fastqc
  String java
  String multiqc

  # optional fastqc arguments
  Int? num_kmers
  Int kmers = select_first([num_kmers, 7])
  String? contaminants_file
  String contaminants = select_first([contaminants_file, ""])
  String? adapters_file
  String adapters = select_first([adapters_file, ""])

  scatter (in_file in fastq_files) {
    call run_fastqc {
      input:
        fastqc = fastqc,
        fastq_file = in_file,
        java = java,
        kmers = kmers,
        contaminants = contaminants,
        adapters = adapters
    }

    call copy {
      input:
        files = [run_fastqc.out_zip, run_fastqc.out_report],
        destination = final_out_dir    
    }
  }
}

task run_fastqc {
  String fastqc
  String fastq_file
  String java
  Int kmers
  String contaminants
  String adapters

  String contaminants_opt = if contaminants != "" then "--contaminants " + contaminants else ""
  String adapters_opt = if adapters != "" then "--adapters " + adapters else ""
  String filename = sub(sub(basename(fastq_file), ".fastq", ""), ".gz", "")

  command {
    mkdir ${filename}
    ${fastqc} -o ${filename} -j ${java} -k ${kmers} ${contaminants_opt} ${adapters_opt} ${fastq_file}
  }
  output {
    File out_zip = "${filename}/${filename}_fastqc.zip"
    File out_report = "${filename}/${filename}_fastqc.html"
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
