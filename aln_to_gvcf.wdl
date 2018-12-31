workflow HaplotypeCaller_sl {
  String sample_name
  File input_bam
  File input_bam_index

  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File scattered_calling_intervals_list

  Boolean? make_gvcf
  Boolean making_gvcf = select_first([make_gvcf,true])

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  String? gatk_path_override
  String gatk_path = select_first([gatk_path_override, "/gatk/gatk"])

  #is the input a cram file?
  Boolean is_cram = sub(basename(input_bam), ".*\\.", "") == "cram"

  String output_suffix = if making_gvcf then ".g.vcf.gz" else ".vcf.gz"
  String output_filename = sample_name + output_suffix

  if ( is_cram ) {
    call CramToBamTask {
          input:
            input_cram = input_bam,
            sample_name = sample_name,
            ref_dict = ref_dict,
            ref_fasta = ref_fasta,
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
        make_gvcf = making_gvcf,
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

  # Put the final output files in an organized manner
  call Moritsuke {
    input:
      sample_name = sample_name,
      gvcf_filename = MergeGVCFs.output_vcf,
      gvcf_index_filename = MergeGVCFs.output_vcf_index
  }

  # Outputs that will be retained when execution is complete
  output {
    File output_vcf = Moritsuke.output_vcf
    File output_vcf_index = Moritsuke.output_vcf_index
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

  # Runtime parameters
  Int? mem_gb
  Int machine_mem_gb = select_first([mem_gb, 7])

  command {
    set -e
    set -o pipefail

    samtools view -h -T ${ref_fasta} ${input_cram} |
    samtools view -b -o ${sample_name}.bam -
    samtools index -b ${sample_name}.bam
    mv ${sample_name}.bam.bai ${sample_name}.bai
  }

  runtime {
    memory: select_first([machine_mem_gb, 15]) + " GB"
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
  Boolean make_gvcf

  String gatk_path
  String? java_options
  String java_opt = select_first([java_options, "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10"])

  # Runtime parameters
  Int? mem_gb
  Int machine_mem_gb = select_first([mem_gb, 7])
  Int command_mem_gb = machine_mem_gb - 1

  command <<<
  set -e
  
    ${gatk_path} --java-options "-Xmx${command_mem_gb}G ${java_opt}" \
      HaplotypeCaller \
      -R ${ref_fasta} \
      -I ${input_bam} \
      -L ${interval_list} \
      -O ${output_filename} \
      ${true="-ERC GVCF" false="" make_gvcf}
  >>>

  runtime {
    memory: machine_mem_gb + " GB"
  }

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
  Int? mem_gb
  Int machine_mem_gb = select_first([mem_gb, 3])
  Int command_mem_gb = machine_mem_gb - 1

  command <<<
  set -e

    ${gatk_path} --java-options "-Xmx${command_mem_gb}G"  \
      MergeVcfs \
      --INPUT ${sep=' --INPUT ' input_vcfs} \
      --OUTPUT ${output_filename}
  >>>

  runtime {
    memory: machine_mem_gb + " GB"
  }

  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}

task Moritsuke {
  # Command parameters
  String sample_name
  File gvcf_filename 
  File gvcf_index_filename

  String gvcf_basename = basename(gvcf_filename)
  String gvcf_index_basename = basename(gvcf_index_filename)

  command {
    set -e 
    set -o pipefail

    mkdir -p ${sample_name}
    mv ${gvcf_filename} ${sample_name}/${gvcf_basename}
    mv ${gvcf_index_filename} ${sample_name}/${gvcf_index_basename}
  }
 
  output {
    File output_vcf = "${sample_name}/${gvcf_basename}"
    File output_vcf_index = "${sample_name}/${gvcf_index_basename}"
  } 
}
