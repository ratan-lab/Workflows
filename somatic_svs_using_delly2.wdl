workflow call_delly_svs {
  File delly
  File exclude
  String prefix
  File reference
  File tumor_bam
  File normal_bam
  Array[File] all_normal_bams
  File tumor_bam_index
  File normal_bam_index
  Array[File] all_normal_bams_index
  File samples
  String final_out_dir

  call delly2 as call_dels {
    input:
      delly = delly,
      type = "DEL",
      exclude = exclude,
      prefix = prefix,
      reference = reference,
      tumor_bam = tumor_bam,
      normal_bam = normal_bam,
      all_normal_bams = all_normal_bams,
      tumor_bam_index = tumor_bam_index,
      normal_bam_index = normal_bam_index,
      all_normal_bams_index = all_normal_bams_index,
      samples = samples
  }

  call delly2 as call_dups {
    input:
      delly = delly,
      type = "DUP",
      exclude = exclude,
      prefix = prefix,
      reference = reference,
      tumor_bam = tumor_bam,
      normal_bam = normal_bam,
      all_normal_bams = all_normal_bams,
      tumor_bam_index = tumor_bam_index,
      normal_bam_index = normal_bam_index,
      all_normal_bams_index = all_normal_bams_index,
      samples = samples
  }

  call delly2 as call_invs {
    input:
      delly = delly,
      type = "INV",
      exclude = exclude,
      prefix = prefix,
      reference = reference,
      tumor_bam = tumor_bam,
      normal_bam = normal_bam,
      all_normal_bams = all_normal_bams,
      tumor_bam_index = tumor_bam_index,
      normal_bam_index = normal_bam_index,
      all_normal_bams_index = all_normal_bams_index,
      samples = samples
  }

  call delly2 as call_bnds {
    input:
      delly = delly,
      type = "BND",
      exclude = exclude,
      prefix = prefix,
      reference = reference,
      tumor_bam = tumor_bam,
      normal_bam = normal_bam,
      all_normal_bams = all_normal_bams,
      tumor_bam_index = tumor_bam_index,
      normal_bam_index = normal_bam_index,
      all_normal_bams_index = all_normal_bams_index,
      samples = samples
  }

  call delly2 as call_inss {
    input:
      delly = delly,
      type = "INS",
      exclude = exclude,
      prefix = prefix,
      reference = reference,
      tumor_bam = tumor_bam,
      normal_bam = normal_bam,
      all_normal_bams = all_normal_bams,
      tumor_bam_index = tumor_bam_index,
      normal_bam_index = normal_bam_index,
      all_normal_bams_index = all_normal_bams_index,
      samples = samples
  }

  call copy {
    input:
      files = [call_dels.bcffile, call_dups.bcffile, call_invs.bcffile, call_bnds.bcffile, call_inss.bcffile],
      destination = final_out_dir
  }
}

task delly2 {
  File delly
  String type
  File exclude
  String prefix
  File reference
  File tumor_bam
  File tumor_bam_index
  File normal_bam
  File normal_bam_index
  Array[File] all_normal_bams
  Array[File] all_normal_bams_index
  File samples

  command <<<
    ${delly} call -t ${type} -x ${exclude} -o ${prefix}.${type}.bcf -g ${reference} ${tumor_bam} ${normal_bam}

    ${delly} filter -f somatic -o ${prefix}.${type}.pre.bcf -s ${samples} ${prefix}.${type}.bcf

    ${delly} call -t ${type} -x ${exclude} -g ${reference} -v ${prefix}.${type}.pre.bcf -o ${prefix}.${type}.geno.bcf ${tumor_bam} ${sep=' ' all_normal_bams} 

    ${delly} filter -f somatic -o ${prefix}.${type}.somatic.bcf -s ${samples} ${prefix}.${type}.geno.bcf
  >>>

  output {
    File bcffile = "${prefix}.${type}.somatic.bcf"
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
