workflow CreateSlPON {
  File ref_fasta
  File ref_fasta_dict
  File ref_fasta_index
  File input_bam
  File input_bai
  String sample
  String gatk_path
  File scattered_calling_intervals_list

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  scatter (interval_file in scattered_calling_intervals) {
    call Mutect {
      input:
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_fasta_dict = ref_fasta_dict,
        sample = sample,
        input_bam = input_bam,
        input_bai = input_bai,
        gatk_path = gatk_path,
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
  File input_bam
  File input_bai
  String sample
  File interval_file
 
  # --max-mnp-distance 0 has to be added to resolve a bug in GenomicsDBImport.
  # See discussion here: https://gatkforums.broadinstitute.org/gatk/discussion/
  # 23496/genomicsdbimport-does-not-support-gvcfs-with-mnps-gatk-v4-1-0-0  
  command <<<
    set -e

    ${gatk_path} --java-options "-Xmx4g" \
      Mutect2 \
      -R ${ref_fasta} \
      -I ${input_bam} \
      -tumor ${sample} \
      -L ${interval_file} \
      --max-mnp-distance 0 \
      -O normal.vcf.gz

    # sometimes the name of the sample is kept as NORMAL, which is a problem in
    # a pipeline where we want to analyze several of these samples. If that is
    # the case, then we should rename the sample in the VCF file
    name=$(gzip -dc normal.vcf.gz | head -2000 | grep "^#CHROM" | cut -f 10)
    if [ "${name}" != "${sample}" ]; then 
        ${gatk_path} --java-options "-Xmx4g" \
          RenameSampleInVcf \
          --INPUT=normal.vcf.gz \
          --OUTPUT=${sample}.vcf.gz \
          --NEW_SAMPLE_NAME=${sample}

        ${gatk_path} --java-options "-Xmx4g" \
          IndexFeatureFile \
          -F ${sample}.vcf.gz

        rm normal.vcf.gz
    else
        mv normal.vcf.gz ${sample}.vcf.gz
        mv normal.vcf.gz.tbi ${sample}.vcf.gz.tbi
    fi
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
