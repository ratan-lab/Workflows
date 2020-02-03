workflow JointGenotyping {
  File unpadded_intervals_file

  String callset_name
  String final_out_dir

  File ref_fasta
  File ref_fasta_index
  File ref_dict

  File dbsnp_vcf
  File dbsnp_vcf_index

  Array[String] sample_names
  Array[File] input_gvcfs 
  Array[File] input_gvcfs_indices 

  String gatk_path

  Array[String] snp_recalibration_tranche_values
  Array[String] snp_recalibration_annotation_values
  Array[String] indel_recalibration_tranche_values
  Array[String] indel_recalibration_annotation_values

  File eval_interval_list
  File hapmap_resource_vcf
  File hapmap_resource_vcf_index
  File omni_resource_vcf
  File omni_resource_vcf_index
  File one_thousand_genomes_resource_vcf
  File one_thousand_genomes_resource_vcf_index
  File mills_resource_vcf
  File mills_resource_vcf_index
  File axiomPoly_resource_vcf
  File axiomPoly_resource_vcf_index
  File dbsnp_resource_vcf = dbsnp_vcf
  File dbsnp_resource_vcf_index = dbsnp_vcf_index

  # ExcessHet is a phred-scaled p-value. We want a cutoff of anything more extreme
  # than a z-score of -4.5 which is a p-value of 3.4e-06, which phred-scaled is 54.69
  Float excess_het_threshold = 54.69
  Float snp_filter_level
  Float indel_filter_level
  Int SNP_VQSR_downsampleFactor

  Int num_of_original_intervals = length(read_lines(unpadded_intervals_file))
  Int num_gvcfs = length(input_gvcfs)

  # Make a 2.5:1 interval number to samples in callset ratio interval list
  Int possible_merge_count = floor(num_of_original_intervals / num_gvcfs / 2.5)
  Int merge_count = if possible_merge_count > 1 then possible_merge_count else 1

  call DynamicallyCombineIntervals {
    input:
      intervals = unpadded_intervals_file,
      merge_count = merge_count
  }

  Array[String] unpadded_intervals = read_lines(DynamicallyCombineIntervals.output_intervals)

  scatter (idx in range(length(unpadded_intervals))) {
    # the batch_size value was carefully chosen here as it
    # is the optimal value for the amount of memory allocated
    # within the task; please do not change it without consulting
    # the Hellbender (GATK engine) team!
    call ImportGVCFs {
      input:
        sample_names = sample_names,
        interval = unpadded_intervals[idx],
        workspace_dir_name = "genomicsdb",
        input_gvcfs = input_gvcfs,
        input_gvcfs_indices = input_gvcfs_indices,
        gatk_path = gatk_path,
        batch_size = 50
    }

    call GenotypeGVCFs {
      input:
        workspace_tar = ImportGVCFs.output_genomicsdb,
        interval = unpadded_intervals[idx],
        output_vcf_filename = "output.vcf.gz",
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        ref_dict = ref_dict,
        dbsnp_vcf = dbsnp_vcf,
        dbsnp_vcf_index = dbsnp_vcf_index,
        gatk_path = gatk_path
    }

    call HardFilterAndMakeSitesOnlyVcf {
      input:
        vcf = GenotypeGVCFs.output_vcf,
        vcf_index = GenotypeGVCFs.output_vcf_index,
        excess_het_threshold = excess_het_threshold,
        variant_filtered_vcf_filename = callset_name + "." + idx + ".variant_filtered.vcf.gz",
        sites_only_vcf_filename = callset_name + "." + idx + ".sites_only.variant_filtered.vcf.gz",
        gatk_path = gatk_path
    }
  }

  call GatherVcfs as SitesOnlyGatherVcf {
    input:
      input_vcfs_fofn = HardFilterAndMakeSitesOnlyVcf.sites_only_vcf,
      input_vcf_indexes_fofn = HardFilterAndMakeSitesOnlyVcf.sites_only_vcf_index,
      output_vcf_name = callset_name + ".sites_only.vcf.gz",
      gatk_path = gatk_path
  }

  call IndelsVariantRecalibrator {
    input:
      sites_only_variant_filtered_vcf = SitesOnlyGatherVcf.output_vcf,
      sites_only_variant_filtered_vcf_index = SitesOnlyGatherVcf.output_vcf_index,
      recalibration_filename = callset_name + ".indels.recal",
      tranches_filename = callset_name + ".indels.tranches",
      recalibration_tranche_values = indel_recalibration_tranche_values,
      recalibration_annotation_values = indel_recalibration_annotation_values,
      mills_resource_vcf = mills_resource_vcf,
      mills_resource_vcf_index = mills_resource_vcf_index,
      axiomPoly_resource_vcf = axiomPoly_resource_vcf,
      axiomPoly_resource_vcf_index = axiomPoly_resource_vcf_index,
      dbsnp_resource_vcf = dbsnp_resource_vcf,
      dbsnp_resource_vcf_index = dbsnp_resource_vcf_index,
      gatk_path = gatk_path
  }

  if (num_gvcfs > 10000) {
  call SNPsVariantRecalibratorCreateModel {
      input:
        sites_only_variant_filtered_vcf = SitesOnlyGatherVcf.output_vcf,
        sites_only_variant_filtered_vcf_index = SitesOnlyGatherVcf.output_vcf_index,
        recalibration_filename = callset_name + ".snps.recal",
        tranches_filename = callset_name + ".snps.tranches",
        recalibration_tranche_values = snp_recalibration_tranche_values,
        recalibration_annotation_values = snp_recalibration_annotation_values,
        downsampleFactor = SNP_VQSR_downsampleFactor,
        model_report_filename = callset_name + ".snps.model.report",
        hapmap_resource_vcf = hapmap_resource_vcf,
        hapmap_resource_vcf_index = hapmap_resource_vcf_index,
        omni_resource_vcf = omni_resource_vcf,
        omni_resource_vcf_index = omni_resource_vcf_index,
        one_thousand_genomes_resource_vcf = one_thousand_genomes_resource_vcf,
        one_thousand_genomes_resource_vcf_index = one_thousand_genomes_resource_vcf_index,
        dbsnp_resource_vcf = dbsnp_resource_vcf,
        dbsnp_resource_vcf_index = dbsnp_resource_vcf_index,
        gatk_path = gatk_path
    }

  scatter (idx in range(length(HardFilterAndMakeSitesOnlyVcf.sites_only_vcf))) {
    call SNPsVariantRecalibrator as SNPsVariantRecalibratorScattered {
      input:
        sites_only_variant_filtered_vcf = HardFilterAndMakeSitesOnlyVcf.sites_only_vcf[idx],
        sites_only_variant_filtered_vcf_index = HardFilterAndMakeSitesOnlyVcf.sites_only_vcf_index[idx],
        recalibration_filename = callset_name + ".snps." + idx + ".recal",
        tranches_filename = callset_name + ".snps." + idx + ".tranches",
        recalibration_tranche_values = snp_recalibration_tranche_values,
        recalibration_annotation_values = snp_recalibration_annotation_values,
        model_report = SNPsVariantRecalibratorCreateModel.model_report,
        hapmap_resource_vcf = hapmap_resource_vcf,
        hapmap_resource_vcf_index = hapmap_resource_vcf_index,
        omni_resource_vcf = omni_resource_vcf,
        omni_resource_vcf_index = omni_resource_vcf_index,
        one_thousand_genomes_resource_vcf = one_thousand_genomes_resource_vcf,
        one_thousand_genomes_resource_vcf_index = one_thousand_genomes_resource_vcf_index,
        dbsnp_resource_vcf = dbsnp_resource_vcf,
        dbsnp_resource_vcf_index = dbsnp_resource_vcf_index,
        gatk_path = gatk_path
      }
    }
    call GatherTranches as SNPGatherTranches {
        input:
          input_fofn = SNPsVariantRecalibratorScattered.tranches,
          output_filename = callset_name + ".snps.gathered.tranches",
          gatk_path = gatk_path
    }
  }

  if (num_gvcfs <= 10000){
    call SNPsVariantRecalibrator as SNPsVariantRecalibratorClassic {
      input:
          sites_only_variant_filtered_vcf = SitesOnlyGatherVcf.output_vcf,
          sites_only_variant_filtered_vcf_index = SitesOnlyGatherVcf.output_vcf_index,
          recalibration_filename = callset_name + ".snps.recal",
          tranches_filename = callset_name + ".snps.tranches",
          recalibration_tranche_values = snp_recalibration_tranche_values,
          recalibration_annotation_values = snp_recalibration_annotation_values,
          hapmap_resource_vcf = hapmap_resource_vcf,
          hapmap_resource_vcf_index = hapmap_resource_vcf_index,
          omni_resource_vcf = omni_resource_vcf,
          omni_resource_vcf_index = omni_resource_vcf_index,
          one_thousand_genomes_resource_vcf = one_thousand_genomes_resource_vcf,
          one_thousand_genomes_resource_vcf_index = one_thousand_genomes_resource_vcf_index,
          dbsnp_resource_vcf = dbsnp_resource_vcf,
          dbsnp_resource_vcf_index = dbsnp_resource_vcf_index,
          gatk_path = gatk_path
    }
  }

  # For small callsets (fewer than 1000 samples) we can gather the VCF shards and collect metrics directly.
  # For anything larger, we need to keep the VCF sharded and gather metrics collected from them.
  Boolean is_small_callset = num_gvcfs <= 1000

  scatter (idx in range(length(HardFilterAndMakeSitesOnlyVcf.variant_filtered_vcf))) {
    call ApplyRecalibration {
      input:
        recalibrated_vcf_filename = callset_name + ".filtered." + idx + ".vcf.gz",
        input_vcf = HardFilterAndMakeSitesOnlyVcf.variant_filtered_vcf[idx],
        input_vcf_index = HardFilterAndMakeSitesOnlyVcf.variant_filtered_vcf_index[idx],
        indels_recalibration = IndelsVariantRecalibrator.recalibration,
        indels_recalibration_index = IndelsVariantRecalibrator.recalibration_index,
        indels_tranches = IndelsVariantRecalibrator.tranches,
        snps_recalibration = if defined(SNPsVariantRecalibratorScattered.recalibration) then select_first([SNPsVariantRecalibratorScattered.recalibration])[idx] else select_first([SNPsVariantRecalibratorClassic.recalibration]),
        snps_recalibration_index = if defined(SNPsVariantRecalibratorScattered.recalibration_index) then select_first([SNPsVariantRecalibratorScattered.recalibration_index])[idx] else select_first([SNPsVariantRecalibratorClassic.recalibration_index]),
        snps_tranches = select_first([SNPGatherTranches.tranches, SNPsVariantRecalibratorClassic.tranches]),
        indel_filter_level = indel_filter_level,
        snp_filter_level = snp_filter_level,
        gatk_path = gatk_path
    }

    # for large callsets we need to collect metrics from the shards and gather them later
    if (!is_small_callset) {
      call CollectVariantCallingMetrics as CollectMetricsSharded {
        input:
          input_vcf = ApplyRecalibration.recalibrated_vcf,
          input_vcf_index = ApplyRecalibration.recalibrated_vcf_index,
          metrics_filename_prefix = callset_name + "." + idx,
          dbsnp_vcf = dbsnp_vcf,
          dbsnp_vcf_index = dbsnp_vcf_index,
          interval_list = eval_interval_list,
          ref_dict = ref_dict,
          gatk_path = gatk_path
      }
    }
  }

  # for small callsets we can gather the VCF shards and then collect metrics on it
  if (is_small_callset) {
    call GatherVcfs as FinalGatherVcf {
      input:
        input_vcfs_fofn = ApplyRecalibration.recalibrated_vcf,
        input_vcf_indexes_fofn = ApplyRecalibration.recalibrated_vcf_index,
        output_vcf_name = callset_name + ".vcf.gz",
        gatk_path = gatk_path
    }

    call CollectVariantCallingMetrics as CollectMetricsOnFullVcf {
      input:
        input_vcf = FinalGatherVcf.output_vcf,
        input_vcf_index = FinalGatherVcf.output_vcf_index,
        metrics_filename_prefix = callset_name,
        dbsnp_vcf = dbsnp_vcf,
        dbsnp_vcf_index = dbsnp_vcf_index,
        interval_list = eval_interval_list,
        ref_dict = ref_dict,
        gatk_path = gatk_path
    }

    call copy as cp_small {
      input:
        files = [FinalGatherVcf.output_vcf, FinalGatherVcf.output_vcf_index, CollectMetricsOnFullVcf.detail_metrics_file, CollectMetricsOnFullVcf.summary_metrics_file, DynamicallyCombineIntervals.output_intervals],
        destination = final_out_dir
    }
  }

  # for large callsets we still need to gather the sharded metrics
  if (!is_small_callset) {
    call GatherMetrics {
      input:
        input_details_fofn = select_all(CollectMetricsSharded.detail_metrics_file),
        input_summaries_fofn = select_all(CollectMetricsSharded.summary_metrics_file),
        output_prefix = callset_name,
        gatk_path = gatk_path
    }

    call copy as cp_large {
      input:
        files = [FinalGatherVcf.output_vcf, FinalGatherVcf.output_vcf_index, GatherMetrics.detail_metrics_file, GatherMetrics.summary_metrics_file, DynamicallyCombineIntervals.output_intervals],
        destination = final_out_dir
    }
  }
}

task GetNumberOfSamples {
  File sample_name_map
  command <<<
    wc -l ${sample_name_map} | awk '{print $1}'
  >>>
  runtime {
    memory: "1 GB"
    preemptible: 5
  }
  output {
    Int sample_count = read_int(stdout())
  }
}

task ImportGVCFs {
  Array[String] sample_names
  Array[File] input_gvcfs
  Array[File] input_gvcfs_indices
  String interval

  String workspace_dir_name

  String gatk_path
  Int batch_size

  command <<<
    set -e
    set -o pipefail
    
    python << CODE
    gvcfs = ['${sep="','" input_gvcfs}']
    sample_names = ['${sep="','" sample_names}']

    if len(gvcfs)!= len(sample_names):
      exit(1)

    with open("inputs.list", "w") as fi:
      for i in range(len(gvcfs)):
        fi.write(sample_names[i] + "\t" + gvcfs[i] + "\n") 

    CODE

    # The memory setting here is very important and must be several GB lower
    # than the total memory allocated to the VM because this tool uses
    # a significant amount of non-heap memory for native libraries.
    # Also, testing has shown that the multithreaded reader initialization
    # does not scale well beyond 5 threads, so don't increase beyond that.
    ${gatk_path} --java-options "-Xmx4g -Xms4g" \
    GenomicsDBImport \
    --genomicsdb-workspace-path ${workspace_dir_name} \
    --batch-size ${batch_size} \
    -L ${interval} \
    --sample-name-map inputs.list \
    --reader-threads 5 \
    -ip 500

    tar -cf ${workspace_dir_name}.tar ${workspace_dir_name}

  >>>
  runtime {
    memory: "7 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File output_genomicsdb = "${workspace_dir_name}.tar"
  }
}

task GenotypeGVCFs {
  File workspace_tar
  String interval

  String output_vcf_filename

  File ref_fasta
  File ref_fasta_index
  File ref_dict

  File dbsnp_vcf
  File dbsnp_vcf_index

  String gatk_path

  command <<<
    set -e

    tar -xf ${workspace_tar}
    WORKSPACE=$( basename ${workspace_tar} .tar)

    ${gatk_path} --java-options "-Xmx5g -Xms5g" \
     GenotypeGVCFs \
     -R ${ref_fasta} \
     -O ${output_vcf_filename} \
     -D ${dbsnp_vcf} \
     -G StandardAnnotation \
     --only-output-calls-starting-in-intervals \
     --use-new-qual-calculator \
     -V gendb://$WORKSPACE \
     -L ${interval}
  >>>
  runtime {
    memory: "7 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File output_vcf = "${output_vcf_filename}"
    File output_vcf_index = "${output_vcf_filename}.tbi"
  }
}

task HardFilterAndMakeSitesOnlyVcf {
  File vcf
  File vcf_index
  Float excess_het_threshold

  String variant_filtered_vcf_filename
  String sites_only_vcf_filename
  String gatk_path


  command {
    set -e

    ${gatk_path} --java-options "-Xmx3g -Xms3g" \
      VariantFiltration \
      --filter-expression "ExcessHet > ${excess_het_threshold}" \
      --filter-name ExcessHet \
      -O ${variant_filtered_vcf_filename} \
      -V ${vcf}

    ${gatk_path} --java-options "-Xmx3g -Xms3g" \
      MakeSitesOnlyVcf \
      --INPUT ${variant_filtered_vcf_filename} \
      --OUTPUT ${sites_only_vcf_filename}

  }
  runtime {
    memory: "3.5 GB"
    cpu: "1"
    preemptible: 5
  }
  output {
    File variant_filtered_vcf = "${variant_filtered_vcf_filename}"
    File variant_filtered_vcf_index = "${variant_filtered_vcf_filename}.tbi"
    File sites_only_vcf = "${sites_only_vcf_filename}"
    File sites_only_vcf_index = "${sites_only_vcf_filename}.tbi"
  }
}

task IndelsVariantRecalibrator {
  String recalibration_filename
  String tranches_filename

  Array[String] recalibration_tranche_values
  Array[String] recalibration_annotation_values

  File sites_only_variant_filtered_vcf
  File sites_only_variant_filtered_vcf_index

  File mills_resource_vcf
  File axiomPoly_resource_vcf
  File dbsnp_resource_vcf
  File mills_resource_vcf_index
  File axiomPoly_resource_vcf_index
  File dbsnp_resource_vcf_index

  String gatk_path

  command {
    ${gatk_path} --java-options "-Xmx24g -Xms24g" \
      VariantRecalibrator \
      -V ${sites_only_variant_filtered_vcf} \
      -O ${recalibration_filename} \
      --tranches-file ${tranches_filename} \
      --trust-all-polymorphic \
      -tranche ${sep=' -tranche ' recalibration_tranche_values} \
      -an ${sep=' -an ' recalibration_annotation_values} \
      -mode INDEL \
      --max-gaussians 4 \
      -resource:mills,known=false,training=true,truth=true,prior=12 ${mills_resource_vcf} \
      -resource:axiomPoly,known=false,training=true,truth=false,prior=10 ${axiomPoly_resource_vcf} \
      -resource:dbsnp,known=true,training=false,truth=false,prior=2 ${dbsnp_resource_vcf}
  }
  runtime {
    memory: "26 GB"
    cpu: "5"
    preemptible: 5
  }
  output {
    File recalibration = "${recalibration_filename}"
    File recalibration_index = "${recalibration_filename}.idx"
    File tranches = "${tranches_filename}"
  }
}

task SNPsVariantRecalibratorCreateModel {
  String recalibration_filename
  String tranches_filename
  Int downsampleFactor
  String model_report_filename

  Array[String] recalibration_tranche_values
  Array[String] recalibration_annotation_values

  File sites_only_variant_filtered_vcf
  File sites_only_variant_filtered_vcf_index

  File hapmap_resource_vcf
  File omni_resource_vcf
  File one_thousand_genomes_resource_vcf
  File dbsnp_resource_vcf
  File hapmap_resource_vcf_index
  File omni_resource_vcf_index
  File one_thousand_genomes_resource_vcf_index
  File dbsnp_resource_vcf_index

  String gatk_path

  command {
    ${gatk_path} --java-options "-Xmx100g -Xms100g" \
      VariantRecalibrator \
      -V ${sites_only_variant_filtered_vcf} \
      -O ${recalibration_filename} \
      --tranches-file ${tranches_filename} \
      --trust-all-polymorphic \
      -tranche ${sep=' -tranche ' recalibration_tranche_values} \
      -an ${sep=' -an ' recalibration_annotation_values} \
      -mode SNP \
      --sample-every-Nth-variant ${downsampleFactor} \
      --output-model ${model_report_filename} \
      --max-gaussians 6 \
      -resource:hapmap,known=false,training=true,truth=true,prior=15 ${hapmap_resource_vcf} \
      -resource:omni,known=false,training=true,truth=true,prior=12 ${omni_resource_vcf} \
      -resource:1000G,known=false,training=true,truth=false,prior=10 ${one_thousand_genomes_resource_vcf} \
      -resource:dbsnp,known=true,training=false,truth=false,prior=7 ${dbsnp_resource_vcf}
  }
  runtime {
    memory: "104 GB"
    cpu: "20"
    preemptible: 5
  }
  output {
    File model_report = "${model_report_filename}"
  }
}

task SNPsVariantRecalibrator {
  String recalibration_filename
  String tranches_filename
  File? model_report

  Array[String] recalibration_tranche_values
  Array[String] recalibration_annotation_values

  File sites_only_variant_filtered_vcf
  File sites_only_variant_filtered_vcf_index

  File hapmap_resource_vcf
  File omni_resource_vcf
  File one_thousand_genomes_resource_vcf
  File dbsnp_resource_vcf
  File hapmap_resource_vcf_index
  File omni_resource_vcf_index
  File one_thousand_genomes_resource_vcf_index
  File dbsnp_resource_vcf_index

  String gatk_path

  command {
    ${gatk_path} --java-options "-Xmx3g -Xms3g" \
      VariantRecalibrator \
      -V ${sites_only_variant_filtered_vcf} \
      -O ${recalibration_filename} \
      --tranches-file ${tranches_filename} \
      --trust-all-polymorphic \
      -tranche ${sep=' -tranche ' recalibration_tranche_values} \
      -an ${sep=' -an ' recalibration_annotation_values} \
      -mode SNP \
      ${"--input-model " + model_report + " --output-tranches-for-scatter "} \
      --max-gaussians 6 \
      -resource:hapmap,known=false,training=true,truth=true,prior=15 ${hapmap_resource_vcf} \
      -resource:omni,known=false,training=true,truth=true,prior=12 ${omni_resource_vcf} \
      -resource:1000G,known=false,training=true,truth=false,prior=10 ${one_thousand_genomes_resource_vcf} \
      -resource:dbsnp,known=true,training=false,truth=false,prior=7 ${dbsnp_resource_vcf}
  }
  runtime {
    memory: "3.5 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File recalibration = "${recalibration_filename}"
    File recalibration_index = "${recalibration_filename}.idx"
    File tranches = "${tranches_filename}"
  }
}

task GatherTranches {
  Array[File] input_fofn
  String output_filename

  String gatk_path


  command <<<
    set -e
    set -o pipefail
    
      ${gatk_path} --java-options "-Xmx6g -Xms6g" \
      GatherTranches \
      --input ${sep=" --input " input_fofn}  \
      --output ${output_filename}
  >>>
  runtime {
    memory: "7 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File tranches = "${output_filename}"
  }
}

task ApplyRecalibration {
  String recalibrated_vcf_filename
  File input_vcf
  File input_vcf_index
  File indels_recalibration
  File indels_recalibration_index
  File indels_tranches
  File snps_recalibration
  File snps_recalibration_index
  File snps_tranches

  Float indel_filter_level
  Float snp_filter_level

  String gatk_path

  command {
    set -e

    ${gatk_path} --java-options "-Xmx5g -Xms5g" \
      ApplyVQSR \
      -O tmp.indel.recalibrated.vcf \
      -V ${input_vcf} \
      --recal-file ${indels_recalibration} \
      --tranches-file ${indels_tranches} \
      --truth-sensitivity-filter-level ${indel_filter_level} \
      --create-output-variant-index true \
      -mode INDEL

    ${gatk_path} --java-options "-Xmx5g -Xms5g" \
      ApplyVQSR \
      -O ${recalibrated_vcf_filename} \
      -V tmp.indel.recalibrated.vcf \
      --recal-file ${snps_recalibration} \
      --tranches-file ${snps_tranches} \
      --truth-sensitivity-filter-level ${snp_filter_level} \
      --create-output-variant-index true \
      -mode SNP
  }
  runtime {
    memory: "7 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File recalibrated_vcf = "${recalibrated_vcf_filename}"
    File recalibrated_vcf_index = "${recalibrated_vcf_filename}.tbi"
  }
}

task GatherVcfs {
  Array[File] input_vcfs_fofn
  Array[File] input_vcf_indexes_fofn
  String output_vcf_name
  
  String gatk_path

  command <<<
    set -e
    set -o pipefail

    # ignoreSafetyChecks make a big performance difference so we include it in our invocation
    ${gatk_path} --java-options "-Xmx6g -Xms6g" \
    GatherVcfsCloud \
    --ignore-safety-checks \
    --gather-type BLOCK \
    --input ${sep=" --input " input_vcfs_fofn} \
    --output ${output_vcf_name}

    ${gatk_path} --java-options "-Xmx6g -Xms6g" \
    IndexFeatureFile \
    --feature-file ${output_vcf_name}
  >>>
  runtime {
    memory: "7 GB"
    cpu: "2"
    preemptible: 5
  }
  output {
    File output_vcf = "${output_vcf_name}"
    File output_vcf_index = "${output_vcf_name}.tbi"
  }
}

task CollectVariantCallingMetrics {
  File input_vcf
  File input_vcf_index

  String metrics_filename_prefix
  File dbsnp_vcf
  File dbsnp_vcf_index
  File interval_list
  File ref_dict

  String gatk_path

  command {
    ${gatk_path} --java-options "-Xmx6g -Xms6g" \
      CollectVariantCallingMetrics \
      --INPUT ${input_vcf} \
      --DBSNP ${dbsnp_vcf} \
      --SEQUENCE_DICTIONARY ${ref_dict} \
      --OUTPUT ${metrics_filename_prefix} \
      --THREAD_COUNT 8 \
      --TARGET_INTERVALS ${interval_list}
  }
  output {
    File detail_metrics_file = "${metrics_filename_prefix}.variant_calling_detail_metrics"
    File summary_metrics_file = "${metrics_filename_prefix}.variant_calling_summary_metrics"
  }
  runtime {
    memory: "7 GB"
    cpu: 2
    preemptible: 5
  }
}

task GatherMetrics {
  Array[File] input_details_fofn
  Array[File] input_summaries_fofn

  String output_prefix

  String gatk_path

  command <<<
    set -e
    set -o pipefail

    
    ${gatk_path} --java-options "-Xmx2g -Xms2g" \
    AccumulateVariantCallingMetrics \
    --INPUT ${sep=" --INPUT " input_details_fofn} \
    --OUTPUT ${output_prefix}
  >>>
  runtime {
    memory: "3 GB"
    cpu: "1"
    preemptible: 5
  }
  output {
    File detail_metrics_file = "${output_prefix}.variant_calling_detail_metrics"
    File summary_metrics_file = "${output_prefix}.variant_calling_summary_metrics"
  }
}

task DynamicallyCombineIntervals {
  File intervals
  Int merge_count

  command {
    python << CODE
    def parse_interval(interval):
        colon_split = interval.split(":")
        chromosome = colon_split[0]
        dash_split = colon_split[1].split("-")
        start = int(dash_split[0])
        end = int(dash_split[1])
        return chromosome, start, end

    def add_interval(chr, start, end):
        lines_to_write.append(chr + ":" + str(start) + "-" + str(end))
        return chr, start, end

    count = 0
    chain_count = ${merge_count}
    l_chr, l_start, l_end = "", 0, 0
    lines_to_write = []
    with open("${intervals}") as f:
        with open("out.intervals", "w") as f1:
            for line in f.readlines():
                # initialization
                if count == 0:
                    w_chr, w_start, w_end = parse_interval(line)
                    count = 1
                    continue
                # reached number to combine, so spit out and start over
                if count == chain_count:
                    l_char, l_start, l_end = add_interval(w_chr, w_start, w_end)
                    w_chr, w_start, w_end = parse_interval(line)
                    count = 1
                    continue

                c_chr, c_start, c_end = parse_interval(line)
                # if adjacent keep the chain going
                if c_chr == w_chr and c_start == w_end + 1:
                    w_end = c_end
                    count += 1
                    continue
                # not adjacent, end here and start a new chain
                else:
                    l_char, l_start, l_end = add_interval(w_chr, w_start, w_end)
                    w_chr, w_start, w_end = parse_interval(line)
                    count = 1
            if l_char != w_chr or l_start != w_start or l_end != w_end:
                add_interval(w_chr, w_start, w_end)
            f1.writelines("\n".join(lines_to_write))
    CODE
  }

  runtime {
    memory: "3 GB"
    preemptible: 5
  }

  output {
    File output_intervals = "out.intervals"
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
