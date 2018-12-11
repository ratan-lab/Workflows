# Workflows
WDL workflows, input files and configuration files for routine tasks.

Currently, the following workflows are included here:
* trim adapters from the fastq sequences
* run FASTQC on the fastq sequences
* align DNA-seq fastq files to a reference genome 
* align RNA-seq fastq files to a reference genome 

The following workflows are only supported for human genomes
* call SNVs from DNA-seq using GATK4
* call SNVs from RNA-seq using GATK4
* call CNVs from DNA-seq using multiple tools
* call STRs from DNA-seq using lobSTR
* call SVs from DNA-seq using multiple tools
* call somatic SNVs from normal/tumor pairs
* call somatic CNVs from normal/tumor pairs
* call somatic SVs from normal/tumor pairs
* annotate a VCF file using VEP

Some workflows that combine several of the above sub-workflows are also included:
* human DNA-seq fastq -> annotated VCF
* human RNA-seq fastq -> annotated VCF
* human DNA-seq normal & tumor fastq -> annotated VCF

Currently, the following configurations are supported for each of the workflows:
* local
* SLURM 

# Style preference
In the absence of a style guide, the following should be followed:
1) Tab is equal to 2 spaces
2) If the name of a task begins with "X", then it has some unintended consequences (such as deletion of temporary files, which were created via some other task). Do not include such tasks in any other workflow
