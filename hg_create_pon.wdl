import "hg_create_sl_pon.wdl" as sl

workflow CreatePON {
  File inputs

  File ref_fasta
  File ref_fasta_dict
  File ref_fasta_index
  File scattered_calling_intervals_list
  File gnomad_vcf

  String gatk_path

  Array[Array[File]] samples = read_tsv(inputs)

  scatter (sample in samples) {
    call sl.CreateSlPON {
      input:
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        sample = sample[0],
        input_bam = sample[1],
        input_bai = sample[2],
        gatk_path = gatk_path,
        scattered_calling_intervals_list = scattered_calling_intervals_list
    }
  }

  Array[File] interval_list = read_lines(scattered_calling_intervals_list)


  scatter (interval_file in interval_list) {
     call CreatePanel {
       input:
        input_vcfs = CreateSlPON.output_vcf,
        input_vcfs_indexes = CreateSlPON.output_vcf_index,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        gatk_path = gatk_path,
        gnomad_vcf = gnomad_vcf,
        interval = interval_file
    }
  }
  
  call MergeVCF {
    input:
      input_vcfs = CreatePanel.output_vcf,
      input_vcfs_indexes = CreatePanel.output_vcf_index,
      ref_fasta = ref_fasta,
      ref_fasta_index = ref_fasta_index,
      ref_fasta_dict = ref_fasta_dict,
      gatk_path = gatk_path
  }
}

# TASK DEFINITIONS
task CreatePanel {
  Array[File] input_vcfs
  Array[File] input_vcfs_indexes
  File ref_fasta
  File ref_fasta_index
  File ref_fasta_dict
  String gatk_path
  File interval
  File gnomad_vcf

  command <<<
    set -e

    vcfstring=""
    for file in ${sep=' ' input_vcfs}; do
      vcf="-V $file "
      vcfstring=$vcfstring$vcf
    done

    ${gatk_path} --java-options "-Xmx4g" GenomicsDBImport \
      -R ${ref_fasta} --genomicsdb-workspace-path pon_db \
      -L ${interval} --merge-input-intervals \
      $vcfstring

    ${gatk_path} --java-options "-Xmx4g" CreateSomaticPanelOfNormals \
      -R ${ref_fasta} -V gendb://pon_db \
      --germline-resource ${gnomad_vcf} \
      -L ${interval} \
      -O pon.vcf.gz
  >>>

  output {
    File output_vcf = "pon.vcf.gz"
    File output_vcf_index = "pon.vcf.gz.tbi"
  }
}

task MergeVCF {
  Array[File] input_vcfs
  Array[File] input_vcfs_indexes
  String gatk_path  
  File ref_fasta
  File ref_fasta_index
  File ref_fasta_dict

  command <<<
    ${gatk_path} --java-options "-Xmx4g" \
      MergeVcfs \
      --INPUT ${sep=' --INPUT ' input_vcfs} \
      --OUTPUT panel.vcf.gz
  >>>

  output {
    File output_vcf = "panel.vcf.gz"
    File output_vcf_index = "panel.vcf.gz.tbi"
  }
}
