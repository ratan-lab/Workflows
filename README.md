# Workflows
WDL workflows, input files and configuration files for routine tasks.

The following configurations should be supported for each of the workflows:
* local
* SLURM on Rivanna

# Style preference (a work in progress)
In the absence of a style guide, the following should be followed:
1) Tab is equal to 2 spaces
2) All the analyses is to be carried out in the "cromwell-executions" folder, since the duplication strategy is easier to implement this way. At the end of the workflow, all output files should be copied to a location which is determined using the variable "final_out_dir". 
