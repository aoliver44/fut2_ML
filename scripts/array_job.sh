#!/bin/bash

## set the SLURM parameters for the job =================================
#SBATCH --job-name=yasmine_fut2
#SBATCH --output=/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/std_err_out/fut_%A_%a.out
#SBATCH --partition=low # comment out this if you want to switch to spitfire cores
##SBATCH --partition=high
##SBATCH --account=dglemaygrp
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=2g
#SBATCH --time=02:30:00
#SBATCH --array=1-20%20

## ======================================================================

# Pull one single line/filename from the list
# (In Awk, NR==x means where row# is x)
array_cmd=$( awk "NR==$SLURM_ARRAY_TASK_ID" /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/array_cmds_subsetted.txt )

# Run the array command found in file input to awk
# (first load any modules nessary)
module load apptainer/latest

bash -c "$array_cmd"
