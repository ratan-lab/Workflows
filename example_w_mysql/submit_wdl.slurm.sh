#!/bin/bash

#SBATCH --job-name=crom-bwa_aln		# Job name
#SBATCH --cpus-per-task=1		# Number of CPU cores per task
#SBATCH --mem=16000				# Job Memory
#SBATCH --time=5:00:00			# Time limit hrs:min:sec
#SBATCH --output=crom-bwa_aln_%A.out	# Standard output log
#SBATCH --error=crom-bwa_aln_%A.err	# Standard error log
#SBATCH -A somrc				# allocation groups
#SBATCH -p standard				# slurm queue

pwd; hostname; date

### load modules
module load cromwell
module load bwa
module load picard

### Submit cromwell job
java -Xmx16g -Dconfig.file=./cromwell-rivanna_mysql.config \
	-jar $CROMWELLPATH/cromwell-30.1.jar \
	run bwa_aln.wdl \
	--options bwa_aln.options.json \
	--inputs bwa_aln.inputs.json 


