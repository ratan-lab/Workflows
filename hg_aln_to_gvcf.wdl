workflow HaplotypeCaller_sl {
  String sample_name
  File input_bam
  File input_bam_index
  String output_dir

  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File scattered_calling_intervals_list

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  String samtools_path
  String gatk_path

  #is the input a cram file?
  Boolean is_cram = sub(basename(input_bam), ".*\\.", "") == "cram"

  String output_suffix = ".g.vcf.gz"
  String output_filename = sample_name + output_suffix

  if ( is_cram ) {
    call CramToBamTask {
          input:
            input_cram = input_bam,
            sample_name = sample_name,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
            samtools_path = samtools_path,
            ref_fasta_index = ref_fasta_index,
    }
  }

  # Call variants in parallel over grouped calling intervals
  scatter (interval_file in scattered_calling_intervals) {

    # Generate GVCF by interval
    call HaplotypeCaller {
      input:
        input_bam = select_first([CramToBamTask.output_bam, input_bam]),
        input_bam_index = select_first([CramToBamTask.output_bai, input_bam_index]),
        interval_list = interval_file,
        output_filename = output_filename,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        gatk_path = gatk_path
    }
  }

  # Merge per-interval GVCFs
  call MergeGVCFs {
    input:
      input_vcfs = HaplotypeCaller.output_vcf,
      input_vcfs_indexes = HaplotypeCaller.output_vcf_index,
      output_filename = output_filename,
      gatk_path = gatk_path
  }

  # Outputs that will be retained when execution is complete
  output {
    File output_vcf = MergeGVCFs.output_vcf
    File output_vcf_index = MergeGVCFs.output_vcf_index
  }
}

# TASK DEFINITIONS
task CramToBamTask {
  # Command parameters
  File ref_fasta
  File ref_fasta_index
  File ref_dict
  File input_cram
  String sample_name
  String samtools_path

  command {
    set -e
    set -o pipefail

    ${samtools_path} view -h -T ${ref_fasta} ${input_cram} |
    ${samtools_path} view -b -o ${sample_name}.bam -
    ${samtools_path} index -b ${sample_name}.bam
    mv ${sample_name}.bam.bai ${sample_name}.bai
  }

  output {
    File output_bam = "${sample_name}.bam"
    File output_bai = "${sample_name}.bai"
  }
}

# HaplotypeCaller per-sample in GVCF mode
task HaplotypeCaller {
  File input_bam
  File input_bam_index
  File interval_list
  String output_filename
  File ref_dict
  File ref_fasta
  File ref_fasta_index

  String gatk_path
  String? java_options
  String java_opt = select_first([java_options, "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10"])

  # Runtime parameters
  Int machine_mem_gb = 4
  Int command_mem_gb = machine_mem_gb - 1

  command <<<
  set -e
  
    ${gatk_path} --java-options "-Xmx${command_mem_gb}G ${java_opt}" \
      HaplotypeCaller \
      -R ${ref_fasta} \
      -I ${input_bam} \
      -L ${interval_list} \
      -O ${output_filename} \
      -ERC GVCF
  >>>

  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}

# Merge GVCFs generated per-interval for the same sample
task MergeGVCFs {
  Array[File] input_vcfs
  Array[File] input_vcfs_indexes
  String output_filename

  String gatk_path

  # Runtime parameters
  Int machine_mem_gb = 4
  Int command_mem_gb = machine_mem_gb - 1

  command <<<
  set -e

    ${gatk_path} --java-options "-Xmx${command_mem_gb}G"  \
      MergeVcfs \
      --INPUT ${sep=' --INPUT ' input_vcfs} \
      --OUTPUT ${output_filename}
  >>>

  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}
