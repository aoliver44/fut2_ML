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

## Step 3: Average out features from SHAP to futher feature reduce
TaxaHFE does a good job reducing features! It reduced the 6627 taxaonomic features from Metaphlan4 down to an average of 142 features! Still, reducing futher often helps, especially with limited samples ("curse of dimensionality"). In order to reduce the features further, SHAP analysis of the models fit to the **training** data were analyzed. Since we ran TaxaHFE-ML 20 times, we analyzed 20 SHAP analyses. We then ranked the feature by order of mean(abs(SHAP)) values, and then averaged the ranks. The top 10 taxonomic groups (by average rank), were added to the covariates and this new dataset was used for TaxaHFE-ML.

To run this, we created a function and some code for how we used it. Note at this step it is imperative to set ```sv_object = "train"``` in the ```create_omnibus_data()``` function. (Note: this is a poor name of a function; a hold over when there were many more data domains in a different project).

Run scripts/step3_best_average_features.R, in this repo and below:

```
## average out the feature importance using signed SHAP

## load libraries
library(dplyr)
library(ggplot2)
`%!in%` = Negate(`%in%`)
options(warn=-1)

## path for data input
working_dir <- "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/"

## source avg shap rank commands
source(paste0(working_dir, "scripts/average_shap_ranks.R"))

## loop over SHAP analyses and pull out the to 10 features
tmp <- create_omnibus_data(input_dir = paste0(working_dir, "taxahfe_ml_outputs"), response = "secretor_status", model = "rf", feature_pattern_start = "^k_", sv_object = "train")

## get the raw data so we can pull the subsetted features out to make the final input
microbiome_data_for_omnibus <- readr::read_delim(file = paste0(working_dir, "input_for_ml_models/merged_metaphlan_v4-0-6.txt"), num_threads = 6, delim = "\t") %>%
  dplyr::mutate(., clade_name = janitor::make_clean_names(clade_name)) %>%
  tibble::column_to_rownames(., var = "clade_name") %>%
  t() %>%
  as.data.frame() %>%
  tibble::rownames_to_column(., var = "subject_id")

## get metadata for final input and merge with subsetted taxonomic groups
metadata <- readr::read_csv(paste0(working_dir, "input_for_ml_models/dietML_microbe.csv"))
subsetted_data <- merge(metadata, microbiome_data_for_omnibus, by = "subject_id") %>%
  dplyr::select(., dplyr::all_of(colnames(metadata)), dplyr::all_of(tmp))

## write to file
write.csv(x = subsetted_data, file = paste0(working_dir, "input_for_ml_models/subsetted_data.csv"), append = F, quote = F, row.names = F)

## write run file for the subsetted data, now just using dietML and not TaxaHFE-ML (no more taxonomic engineering)
run_file_subsetted <- data.frame(program=character(), response=character(),
                       response_col=character(), dataset1=character(),
                       dataset2=character(), model=character())

run_file_subsetted <- run_file_subsetted %>% dplyr::add_row(
  program = "dietml",
  response = "secretor_status_subsetted",
  response_col = "feature_of_interest",
  dataset1 = "subsetted_data.csv",
  dataset2 = NULL,
  model = "rf"
)

## write run file to file
write.table(x = run_file_subsetted, file = paste0(working_dir, "input_for_ml_models/run_file_subsetted.txt"), sep = "\t", row.names = F, append = F, quote = F)
```

## Step 4: Make dietML commands to run subsetted data
The final run with the subsetted data uses a slightly different program - basically the program that TaxaHFE-ML feeds into (we call it dietML, it is a ML pipeline). The process of this is the same as step2 though!

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

echo "Making DietML subsetted commands..."
while read program response response_col dataset1 dataset2 model; do
    while read SEED; do
    echo "mkdir -p ${WORKDIR}taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ && apptainer run --cwd /app --no-home -C --workdir \$(mktemp -d -p ${WORKDIR}taxahfe_ml_outputs/apptainer_temp/) --bind ${WORKDIR}:/data ${DIETML_SINGULARITY} /data/input_for_ml_models/${dataset1} -o /data/taxahfe_ml_outputs/${response}/${model}/output_${SEED}/ -s subject_id -t factor --parallel_workers 4 --model ${model} -l feature_of_interest -n 2 --metric bal_accuracy -c 0.95 --vif_threshold 10 --vif_preference /data/input_for_ml_models/vif_preference.txt --pct_loss 0 --info_gain_n 0 --train_split 0.80 --tune_time 5 --tune_length 80 --tune_stop 30 --folds 10 --cv_repeats 3 --shap --seed ${SEED}" >> ${WORKDIR}taxahfe_ml_outputs/array_cmds_subsetted.txt
    done < <(cat ${WORKDIR}input_for_ml_models/random_seeds.txt)
done < <(grep "dietml" ${WORKDIR}input_for_ml_models/run_file_subsetted.txt)
```

## Step 5: Analyze the outputs of the DietML, subsetted data, run!
Same idea as step 3, but in this case we will fit the model to the full datasets, and average the feature ranks! Since we are no longer doing a feature engineering step, we analyze feature importance with the most data possible (this is how the Python SHAP pacakge people do it). Again, critically here we change ```sv_object = "full"``` in the ```create_omnibus_data()``` function.

```
## average out the feature importance using signed SHAP - post subset

## load libraries
library(dplyr)
library(ggplot2)
`%!in%` = Negate(`%in%`)
options(warn=-1)

## path for data input
working_dir <- "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/"

## source avg shap rank commands
source(paste0(working_dir, "scripts/average_shap_ranks.R"))

rf_subsetted <- create_omnibus_data(input_dir = paste0(working_dir, "taxahfe_ml_outputs"), response = "secretor_status_subsetted", model = "rf", feature_pattern_start = "^k_", sv_object = "full")
## load an example full data that has been pre-processed
attach(paste0(working_dir, "taxahfe_ml_outputs/secretor_status_subsetted/rf/output_131465/ml_analysis/shap_inputs_dietml_131465.RData"), warn.conflicts = FALSE)

## pull out subject id and label (feature of interest)
feature_of_interest <- split_from_data_frame$data %>% dplyr::select(., subject_id, feature_of_interest)

## correlate feature of interest with each feature and assign sign of correlation to shap value
correlation_response <- cbind(feature_of_interest, shap_data_full)
correlation_response <- correlation_response %>%
  dplyr::mutate(., feature_of_interest = ifelse(feature_of_interest == "secretor", 1, 0)) %>%
  correlation::correlation(method = "spearman") %>% 
  dplyr::filter(., grepl("feature_of_interest", Parameter1) | grepl("feature_of_interest", Parameter2)) %>%
  dplyr::mutate(., abs_cor = ifelse(rho < 0, -1, 1)) %>%
  dplyr::select(., Parameter2, abs_cor)
signed_shap <- merge(secretor_status_subsetted_rf_raw_ranks, correlation_response, by.x = "feature", by.y = "Parameter2")
signed_shap <- signed_shap %>% dplyr::mutate(., signed_shap = (mean_shap * abs_cor))

## make plot
signed_shap_plot <- signed_shap %>%
  dplyr::filter(., overall_rank_mean < 11) %>%
  ggplot() + aes(x = reorder(feature, signed_shap), weight = as.numeric(signed_shap)) +
  geom_bar(aes(fill = signed_shap)) +
  coord_flip() +
  scale_fill_gradientn(colors = NatParksPalettes::natparks.pals("Glacier",n=30,type="continuous")) +
  labs(x = "", y = "Mean Signed Shap Value") +
  theme_bw(base_size = 14) + theme(text = element_text(colour = "black"), axis.text = element_text(colour = "black"))
detach()
```
