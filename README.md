# Workflows
WDL workflows, input files and configuration files for routine tasks.

The following configurations should be supported for each of the workflows:
* local
* SLURM on Rivanna

# Current workflows

1. SNV calling for hg38 using GATK4
  - hg38_alns_to_gvcfs.wdl
    - use this to convert CRAM/BAM files from multiple samples into individual GVCFs
    - the inputs file is a tab delimited file with sample name, absolute path of the location of the BAM/CRAM file, absolute path of the location of the BAM/CRAM index
  - hg38_gvcf_to_variants.wdl
    - take all individual GVCFs, and jointly call SNVs 


# Style preference (a work in progress)
In the absence of a style guide, the following should be followed:
1) Tab is equal to 2 spaces
2) All the analyses is to be carried out in the "cromwell-executions" folder, since the duplication strategy is easier to implement this way. At the end of the workflow, all output files should be copied to a location which is determined using the variable "final_out_dir". 
