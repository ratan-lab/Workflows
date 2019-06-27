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
        scattered_calling_intervals_list = scattered_calling_intervals_list
    }
  }

  output {
    Array[File] output_vcfs = CallSomaticSl.output_vcf
    Array[File] output_vcfs_indexes = CallSomaticSl.output_vcf_index
  }
}
