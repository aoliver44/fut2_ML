# TaxaHFE-ML of Fut2 for FL100 cohort

This repository contains the code to reproduce the TaxaHFE-ML results presented in the manuscript:

<i>
Association between Fiber Intake and Gastrointestinal Inflammation is Dependent on FUT2 Secretor Status in Healthy Adults
</i>

<br>

<b>Authors:</b> Yasmine Y. Bouzid, Andrew Oliver, Sarah E. Blecksmith, Stephanie M.G. Wilson, Zeynep Alkan2, Liping Huang, Brian J. Bennett, Mary E. Kable, Charles B. Stephensen, Danielle G. Lemay 


Other analytical code for the manuscript can be found in [this](https://github.com/YasmineYBouzid/fut2_guthealth_publication) repository.

### Environment the code was run
This analysis was performed on the UC Davis HIVE HPC, using an Apptainer installation of TaxaHFE-ML (v2.4.1). Averaging out the features using SHAP requires very few packages. These packages exist in a different Apptainer container that was built for other analyses. It is likely overkill for your needs, but it has all the pacakges needed, and is linked below. 

## Step 1: Generate TaxaHFE-ML run file
This step generates a list of commands to be run as an array job on the HIVE HPC. See scripts/step1_make_run_file.R. Essentially:

```
## make run file for taxaHFE_runs
library(dplyr)
set.seed(12345)

## make a list of random seeds
random_seeds <- sample(1:10000000, size = 20, replace = F)

## path for data input
input_for_ml_models <- "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/"

## write random seeds to file
readr::write_lines(random_seeds, file = paste0(input_for_ml_models, "random_seeds.txt"), append = F)

## write run file
run_file <- data.frame(program=character(), response=character(),
                       response_col=character(), dataset1=character(),
                       dataset2=character(), model=character())

run_file <- run_file %>% dplyr::add_row(
  program = "taxahfe",
  response = "secretor_status",
  response_col = "feature_of_interest",
  dataset1 = "dietML_microbe.csv",
  dataset2 = "merged_metaphlan_v4-0-6.txt",
  model = "rf"
)

write.table(x = run_file, file = paste0(input_for_ml_models, "run_file.txt"), sep = "\t", row.names = F, append = F, quote = F)
```

## Step 2: Generate array commands
Next we loop over the run file and the random seeds to generate the array commands using a shell script (see scripts/step2_make_array_cmds.sh):

```
#!/bin/bash -e

# variables
DIETML_SINGULARITY=/quobyte/dglemaygrp/aoliver/software/diet_ml_2_4_1.sif
TAXAHFE_SINGULARITY=/quobyte/dglemaygrp/aoliver/software/taxahfe_ml_2_4_1.sif
WORKDIR=/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/

## cd into working directory
cd ${WORKDIR}

mkdir -p ${WORKDIR}taxahfe_ml_outputs/apptainer_temp/
mkdir -p ${WORKDIR}taxahfe_ml_outputs/std_err_out/

echo "Making TaxaHFE commands..."
while read program response response_col dataset1 dataset2 model; do
    while read SEED; do
    echo "mkdir -p ${WORKDIR}taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ && apptainer run --cwd /app --no-home -C --workdir \$(mktemp -d -p ${WORKDIR}taxahfe_ml_outputs/apptainer_temp/) --bind ${WORKDIR}:/data ${TAXAHFE_SINGULARITY} /data/input_for_ml_models/${dataset1} /data/input_for_ml_models/${dataset2} -o /data/taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ -s subject_id -t factor -L 3 --nperm 40 --parallel_workers 4 --model ${model} -l feature_of_interest -n 2 --metric bal_accuracy -c 0.95 --vif_threshold 10 --vif_preference /data/input_for_ml_models/vif_preference.txt --pct_loss 0 --info_gain_n 0 --train_split 0.80 --tune_time 5 --tune_length 80 --tune_stop 30 --folds 10 --cv_repeats 3 --shap --seed ${SEED}" >> ${WORKDIR}taxahfe_ml_outputs/array_cmds.txt
    done < <(cat ${WORKDIR}input_for_ml_models/random_seeds.txt)
done < <(grep "taxahfe" ${WORKDIR}input_for_ml_models/run_file.txt)
```

The parameters used for Taxahfe-ML are as follows (almost all are defaults for TaxaHFE-ML):

- ```-s``` (subject identified): subject_id
- ```-t``` (feature type): factor
- ```-L``` (lowest taxonomic level for TaxaHFE-ML): 3
- ```-nperm``` (number of RF permutations in the TaxaHFE-ML competitions): 40
- ```--parallel_workers``` (number of parallel R session when usuable): 4
- ```--model``` (ML model engine to run): rf (random forest)
- ```-l``` (response label): feature_of_interest
- ```-n``` (number of cores to use): 2
- ```--metric``` (metric to optimize for ML, ie loss function): bal_accuracy (balanced acuracy)
- ```-c``` (correlation level for TaxaHFE competition and ML feature engineering): 0.95
- ```--vif_threshold``` (variance inflation factor threshold from pkg collinear): 10
- ```--vif_preference``` (preference of features to retain on VIF analysis): path to file (see data/vif_preference.txt)
- ```--pct_loss``` (prefer a more regularized model at expense to accuracy): 0 
- ```--info_gain_n``` (keep only n features in feature engineering based on information gain): 0 (bypass filter)
- ```--train_split``` (train-test split): 80% train, 20% test
- ```--tune_time``` (allow HP tuning for n minutes): 5 minutes
- ```--tune_length``` (limit HP tune combinations): 80
- ```--tune_stop``` (stop tuning if no increase in performance for n combinations): 30
- ```--folds``` (k folds for cross validation): 10
- ```cv_repeats``` (n repeats for repeated cross validation): 3
- ```--shap``` (run shap analysis): TRUE
- ```--seed``` (random seed): random number

