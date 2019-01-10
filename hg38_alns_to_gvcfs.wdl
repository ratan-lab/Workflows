import "hg38_aln_to_gvcf.wdl" as sl

workflow HaplotypeCaller_ml {
    File inputs

    File ref_dict
    File ref_fasta
    File ref_fasta_index
    File scattered_calling_intervals_list
    String gatk_path

    Array[Array[File]] samples = read_tsv(inputs)

    scatter (sample in samples) {
        call sl.HaplotypeCaller_sl {
            input: 
                sample_name = sample[0],
                input_bam = sample[1],
                input_bam_index = sample[2],
                output_dir = sample[3],
                ref_dict = ref_dict,
                ref_fasta = ref_fasta,
                ref_fasta_index = ref_fasta_index,
                scattered_calling_intervals_list = scattered_calling_intervals_list,
                gatk_path = gatk_path,
        }
    }
}

