#!/bin/bash

## set the SLURM parameters for the job =================================
#SBATCH --job-name=collect_ml_scres
#SBATCH --output=/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/collect_ml_scores_%A_%a.out
##SBATCH --partition=low # comment out this if you want to switch to spitfire cores
#SBATCH --partition=high
#SBATCH --account=dglemaygrp
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=2g
#SBATCH --time=02:30:00


cd /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/

while read program response response_col dataset1 dataset2 model; do
  if [ -d "${response}/${model}" ]; then
  cd ${response}/${model}/;
  for f in output*; do
    seed=$(echo ${f} | sed "s/output_//g")
    if grep -q "bal_accuracy (test" ${f}/*${seed}.log; then
      g=$(grep -m1 "bal_accuracy (test" ${f}/*${seed}.log | awk -F'[:]' '{print $4}');
      i=$(grep -m1 "bal_accuracy (train" ${f}/*${seed}.log | awk -F'[:]' '{print $4}');
      echo ${response} ${program} ${model} ${seed} ${g} ${i} >> /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/tmp_scores_$(date +"%m_%d_%y").txt;
    fi;
  done;
  cd /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/
  fi
done < /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/run_file.txt

## run if taxahfe_subsetted
if [ -d /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/secretor_status_subsetted/ ]; then
  while read program response response_col dataset1 dataset2 model; do
  if [ -d "${response}/${model}" ]; then
  cd ${response}/${model}/;
  for f in output*; do
    seed=$(echo ${f} | sed "s/output_//g")
    if grep -q "bal_accuracy (test" ${f}/*${seed}.log; then
      g=$(grep -m1 "bal_accuracy (test" ${f}/*${seed}.log | awk -F'[:]' '{print $4}');
      i=$(grep -m1 "bal_accuracy (train" ${f}/*${seed}.log | awk -F'[:]' '{print $4}');
      echo ${response} ${program} ${model} ${seed} ${g} ${i} >> /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/tmp_scores_$(date +"%m_%d_%y").txt;
    fi;
  done;
  cd /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/
  fi
  done < <(grep "secretor_status" /quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/run_file.txt | sed 's,secretor_status,secretor_status_subsetted,g')
fi
