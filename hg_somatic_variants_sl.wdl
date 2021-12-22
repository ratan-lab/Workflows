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
      input_stats = Mutect.output_stats,
      input_model = Mutect.model,
      gatk_path = gatk_path,
      sample = sample    
  }

  output {
    File output_vcf = MergeVCFs.output_vcf
    File output_vcf_index = MergeVCFs.output_vcf_index
    File output_stats = MergeVCFs.output_stats
    File output_model = MergeVCFs.output_model
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
      --f1r2-tar-gz f1r2.tar.gz \
      --genotype-germline-sites true \
      --genotype-pon-sites true \
      -L ${interval_file} \
      -O ${sample}.vcf.gz
  >>>

  output {
    File output_vcf = "${sample}.vcf.gz"
    File output_vcf_index = "${sample}.vcf.gz.tbi"
    File output_stats = "${sample}.vcf.gz.stats"
    File model = "f1r2.tar.gz"
  }
}

task MergeVCFs {
  Array[File] input_vcfs
  Array[File] input_vcfs_indexes
  Array[File] input_stats
  Array[File] input_model
  String sample
  String gatk_path

  command <<<
  set -e

    ${gatk_path} --java-options "-Xmx4g"  \
      MergeVcfs \
      --INPUT ${sep=' --INPUT ' input_vcfs} \
      --OUTPUT ${sample}.vcf.gz

    ${gatk_path} --java-options "-Xmx4g" \
        MergeMutectStats \
        -stats ${sep=' -stats ' input_stats} \
        -O ${sample}.vcf.gz.stats

    ${gatk_path} --java-options "-Xmx4g" \
        LearnReadOrientationModel \
        -I ${sep=' -I ' input_model} \
        -O read-orientation-model.tar.gz
  >>>

  output {
    File output_vcf = "${sample}.vcf.gz"
    File output_vcf_index = "${sample}.vcf.gz.tbi"
    File output_stats = "${sample}.vcf.gz.stats"
    File output_model = "read-orientation-model.tar.gz"
  }
} 
