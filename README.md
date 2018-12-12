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
* SLURM on Rivanna

# Rivanna
The current configuration needs to be modified depending on the workflow. Specifically the following variables are defined and may need to be changed for the specific workflow

concurrent-job-limit = 500
runtime-attributes = """
Int nodes = 1
Int ntasks = 1
Int cpus = 1
String time = "1-00:00:00"
String partition = "parallel"
Int requested_mem_per_cpu = 6000
String account = "ratan"
"""

# Style preference
In the absence of a style guide, the following should be followed:
1) Tab is equal to 2 spaces
2) If the name of a task begins with "X", then it has some unintended consequences (such as deletion of temporary files, which were created via some other task). Do not include such tasks in any other workflow
