workflow fastqc {
  Array[String] fastq_files
  Boolean multiple_files = length(fastq_files) > 1
  String out_dir

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

  # create output directory if needed
  call create_dir {
    input:
      dir = out_dir
  }

  scatter (in_file in fastq_files) {
    call run_fastqc {
      input:
        fastqc = fastqc,
        fastq_file = in_file,
        java = java,
        out_dir = create_dir.dir_path,
        kmers = kmers,
        contaminants = contaminants,
        adapters = adapters
    }
  }

  # if more than one fastq file, run multiqc
  if (multiple_files){
    call run_multiqc {
      input:
        dir = run_fastqc.dir[0],
        multiqc = multiqc
    }
  }

}

task create_dir {
  String dir
  command {
    mkdir -p ${dir}
  }
  output {
    String dir_path = dir
  }
}

task run_fastqc {
  String fastqc
  String fastq_file
  String java
  String out_dir
  Int kmers
  String contaminants
  String adapters

  String contaminants_opt = if contaminants != "" then "--contaminants " + contaminants else ""
  String adapters_opt = if adapters != "" then "--adapters " + adapters else ""
  String filename = sub(sub(basename(fastq_file), ".fastq", ""), ".gz", "")

  command {
    ${fastqc} -o ${out_dir} -j ${java} -k ${kmers} ${contaminants_opt} ${adapters_opt} ${fastq_file}
  }
  output {
    File out_zip = "${out_dir}/${filename}_fastqc.zip"
    File out_report = "${out_dir}/${filename}_fastqc.html"
    String dir = out_dir
  }
}

task run_multiqc {
  String dir
  String multiqc

  command {
    ${multiqc} -f -o ${dir} ${dir}
  }
 output {
    File main_report = "${dir}/multiqc_report.html"
    File stats_report_1 = "${dir}/multiqc_data/multiqc_fastqc.txt"
    File stats_report_2 = "${dir}/multiqc_data/multiqc_general_stats.txt"
    File source_report = "${dir}/multiqc_data/multiqc_sources.txt"
  }
}