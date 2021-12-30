import "hg_somatic_variants_sl.wdl" as sl

workflow CallSomatic {
  File inputs
  File ref_fasta
  File ref_fasta_dict
  File ref_fasta_index
  File gnomad
  File gnomad_index
  File ponvcf
  File ponvcf_index
  File exac_vcf
  File exac_tbi
  File scattered_calling_intervals_list

  String gatk_path

  Array[Array[File]] samples = read_tsv(inputs)

  scatter (sample in samples) {
    call sl.CallSomaticSl {
      input:
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        gnomad = gnomad,
        gnomad_index = gnomad_index,
        ponvcf = ponvcf,
        ponvcf_index = ponvcf_index,
        sample = sample[0],
        normal_bam = sample[1],
        normal_bai = sample[2],
        tumor_bam = sample[3],
        tumor_bai = sample[4],
        gatk_path = gatk_path,
        exac_vcf = exac_vcf,
        exac_tbi = exac_tbi,
        scattered_calling_intervals_list = scattered_calling_intervals_list
    }

    call FilterCalls {
      input:
        vcf = CallSomaticSl.output_vcf,
        vcf_index = CallSomaticSl.output_vcf_index,
        vcf_stats = CallSomaticSl.output_stats,
        model = CallSomaticSl.output_model,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        segments = CallSomaticSl.segments,
        contamination = CallSomaticSl.contamination,   
        gatk_path = gatk_path
    }
  }

  output {
    Array[File] output_vcfs = FilterCalls.output_vcf
    Array[File] output_vcfs_indexes = FilterCalls.output_vcf_index
    Array[File] output_vcfs_stats = FilterCalls.output_vcf_stats
  }
}

task FilterCalls {
  File vcf
  File vcf_index
  File vcf_stats
  File ref_fasta
  File ref_fasta_index
  File ref_fasta_dict
  File gatk_path
  File model
  File segments
  File contamination

  String output_file = basename(vcf, ".vcf.gz") + ".filtered.vcf.gz"

  command <<<
    ${gatk_path} FilterMutectCalls \
        -R ${ref_fasta} -V ${vcf} \
        --tumor-segmentation ${segments} \
        --contamination-table ${contamination} \
        --ob-priors ${model} \
        -O ${output_file}
  >>>   

  output {
    File output_vcf = "${output_file}"
    File output_vcf_index = "${output_file}.tbi"
    File output_vcf_stats = "${output_file}.filteringStats.tsv"
  }
}
