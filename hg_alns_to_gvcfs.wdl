import "hg_aln_to_gvcf.wdl" as sl

workflow HaplotypeCaller_ml {
  File inputs

  File ref_dict
  File ref_fasta
  File ref_fasta_index
  File scattered_calling_intervals_list
  String gatk_path
  String samtools_path
  String final_out_dir

  Array[Array[File]] samples = read_tsv(inputs)

  scatter (sample in samples) {
      call sl.HaplotypeCaller_sl {
          input: 
              sample_name = sample[0],
              input_bam = sample[1],
              input_bam_index = sample[2],
              output_dir = sample[0],
              ref_dict = ref_dict,
              ref_fasta = ref_fasta,
              ref_fasta_index = ref_fasta_index,
              scattered_calling_intervals_list = scattered_calling_intervals_list,
              gatk_path = gatk_path,
              samtools_path = samtools_path,
      }

    call copy {
      input:    
        files = [HaplotypeCaller_sl.output_vcf, HaplotypeCaller_sl.output_vcf_index],
        destination = final_out_dir
    }
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
