#!/bin/bash -e

# variables
DIETML_SINGULARITY=/quobyte/dglemaygrp/aoliver/software/diet_ml_2_4_1.sif
TAXAHFE_SINGULARITY=/quobyte/dglemaygrp/aoliver/software/taxahfe_ml_2_4_1.sif
WORKDIR=/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/

## cd into working directory
cd ${WORKDIR}

mkdir -p ${WORKDIR}taxahfe_ml_outputs/apptainer_temp/
mkdir -p ${WORKDIR}taxahfe_ml_outputs/std_err_out/

# echo "Making DietML commands..."
# while read program response response_col dataset1 dataset2 time; do
#     while read SEED; do
#     echo "mkdir -p ${WORKDIR}random_forest/${response}/${program}/${time}/output_${SEED}/ && apptainer run --cwd /app --no-home -C --workdir \$(mktemp -d -p ${WORKDIR}random_forest/apptainer_temp/) --bind ${WORKDIR}:/data ${DIETML_SINGULARITY} /data/input_data_for_models/${dataset1} -o /data/random_forest/${response}/${program}/${time}/output_${SEED}/ -s short_id -t numeric --parallel_workers 4 --model rf -l growth_metric -n 2 --metric rsq -c 0.95 --vif_threshold 10 --vif_preference /data/input_data_for_models/milq_growth_vif_preference.txt --pct_loss 0 --info_gain_n 0 --train_split 0.80 --tune_time 5 --tune_length 80 --tune_stop 30 --folds 10 --cv_repeats 3 --shap --seed ${SEED}" >> ${WORKDIR}random_forest/array_cmds.txt
#     done < <(cat ${WORKDIR}input_data_for_models/random_seeds.txt)
# done < <(grep "dietml" ${WORKDIR}input_data_for_models/run_file.txt | grep -v "wfa") # not wfa

echo "Making TaxaHFE commands..."
while read program response response_col dataset1 dataset2 model; do
    while read SEED; do
    echo "mkdir -p ${WORKDIR}taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ && apptainer run --cwd /app --no-home -C --workdir \$(mktemp -d -p ${WORKDIR}taxahfe_ml_outputs/apptainer_temp/) --bind ${WORKDIR}:/data ${TAXAHFE_SINGULARITY} /data/input_for_ml_models/${dataset1} /data/input_for_ml_models/${dataset2} -o /data/taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ -s subject_id -t factor -L 3 --nperm 40 --parallel_workers 4 --model ${model} -l feature_of_interest -n 2 --metric bal_accuracy -c 0.95 --vif_threshold 10 --vif_preference /data/input_for_ml_models/vif_preference.txt --pct_loss 0 --info_gain_n 0 --train_split 0.80 --tune_time 5 --tune_length 80 --tune_stop 30 --folds 10 --cv_repeats 3 --shap --seed ${SEED}" >> ${WORKDIR}taxahfe_ml_outputs/array_cmds.txt
    done < <(cat ${WORKDIR}input_for_ml_models/random_seeds.txt)
done < <(grep "taxahfe" ${WORKDIR}input_for_ml_models/run_file.txt)

# ## copy over array job shell script and modify
# cp /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/raw_data/array_job.sh ${WORKDIR}random_forest/
# 
# ## edit it to work with current run
# sed "s,STD_OUT_PATH,/quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest,g" /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh > /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh1
# sed "s,ARRAY_LIMIT,1-$(wc -l /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_cmds.txt | awk '{print $1}')%40,g" /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh1 > /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh2
# sed "s,INPUT_ARRAY_CMDS,/quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest,g" /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh2 > /quobyte/dglemaygrp/aoliver/milq/growth/lag_exp/random_forest/array_job.sh3
# rm ${WORKDIR}random_forest/array_job.sh ${WORKDIR}random_forest/array_job.sh1 ${WORKDIR}random_forest/array_job.sh2
# mv ${WORKDIR}random_forest/array_job.sh3 ${WORKDIR}random_forest/array_job.sh
