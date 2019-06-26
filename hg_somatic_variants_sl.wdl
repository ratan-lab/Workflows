workflow CallSomaticSl {
  File ref_fasta
  File ref_fasta_dict
  File ref_fasta_index
  File gnomad
  File gnomad_index
  File ponvcf
  File ponvcf_index
  String sample
  String gatk_path
  File tumor_bam
  File tumor_bai
  File normal_bam
  File normal_bai
  File scattered_calling_intervals_list

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  scatter (interval_file in scattered_calling_intervals) {
    call Mutect {
      input:
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        gnomad = gnomad,
        gnomad_index = gnomad_index,
        sample = sample,
        tumor_bam = tumor_bam,
        tumor_bai = tumor_bai,
        normal_bam = normal_bam,
        normal_bai = normal_bai,
        gatk_path = gatk_path,
        ponvcf = ponvcf,
        ponvcf_index = ponvcf_index,
        interval_file = interval_file
    }
  }

  call MergeVCFs {
    input: 
      input_vcfs = Mutect.output_vcf,
      input_vcfs_indexes = Mutect.output_vcf_index,
      gatk_path = gatk_path,
      sample = sample    
  }

  output {
    File output_vcf = MergeVCFs.output_vcf
    File output_vcf_index = MergeVCFs.output_vcf_index
  }
}

# TASK DEFINITIONS
task Mutect {
  File ref_fasta
  File ref_fasta_index
  File ref_fasta_dict
  String gatk_path
  File tumor_bam
  File tumor_bai
  File normal_bam
  File normal_bai
  String sample
  File ponvcf
  File ponvcf_index
  File gnomad
  File gnomad_index
  File interval_file

  command <<<
    set -e

    ${gatk_path} --java-options "-Xmx4g" \
      Mutect2 \
      -R ${ref_fasta} \
      -I ${tumor_bam} \
      -I ${normal_bam} \
      -normal ${sample} \
      --germline-resource ${gnomad} \
      --panel-of-normals ${ponvcf} \
      -L ${interval_file} \
      -O ${sample}.vcf.gz
  >>>

  output {
    File output_vcf = "${sample}.vcf.gz"
    File output_vcf_index = "${sample}.vcf.gz.tbi"
  }
}

task MergeVCFs {
  Array[File] input_vcfs
  Array[File] input_vcfs_indexes
  String sample
  String gatk_path
  String output_filename = "${sample}.vcf.gz"

  command <<<
  set -e

    ${gatk_path} --java-options "-Xmx4g"  \
      MergeVcfs \
      --INPUT ${sep=' --INPUT ' input_vcfs} \
      --OUTPUT ${output_filename}
  >>>

  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}   
