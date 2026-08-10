## make run file for taxaHFE_runs
library(dplyr)
set.seed(12345)

## make a list of random seeds
random_seeds <- sample(1:10000000, size = 20, replace = F)

## write random seeds to file
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

# run_file <- run_file %>% dplyr::add_row(
#   program = "taxahfe",
#   response = "secretor_status",
#   response_col = "feature_of_interest",
#   dataset1 = "dietML_microbe.csv",
#   dataset2 = "merged_metaphlan_v4-0-6.txt",
#   model = "svm"
# )

# run_file <- run_file %>% dplyr::add_row(
#   program = "taxahfe",
#   response = "secretor_status",
#   response_col = "feature_of_interest",
#   dataset1 = "dietML_microbe.csv",
#   dataset2 = "merged_metaphlan_v4-0-6.txt",
#   model = "xgboost"
# )

# run_file <- run_file %>% dplyr::add_row(
#   program = "taxahfe",
#   response = "secretor_status",
#   response_col = "feature_of_interest",
#   dataset1 = "dietML_microbe.csv",
#   dataset2 = "merged_metaphlan_v4-0-6.txt",
#   model = "mars"
# )

write.table(x = run_file, file = paste0(input_for_ml_models, "run_file.txt"), sep = "\t", row.names = F, append = F, quote = F)
