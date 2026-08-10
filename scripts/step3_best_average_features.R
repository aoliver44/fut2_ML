## average out the feature importance using signed SHAP

## load libraries
library(dplyr)
library(ggplot2)
`%!in%` = Negate(`%in%`)
options(warn=-1)

## source avg shap rank commands
source("/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/scripts/average_shap_ranks.R")

tmp <- create_omnibus_data(input_dir = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs", response = "secretor_status", model = "rf", feature_pattern_start = "^k_", sv_object = "train")
microbiome_data_for_omnibus <- readr::read_delim(file = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/merged_metaphlan_v4-0-6.txt", num_threads = 6, delim = "\t") %>%
  dplyr::mutate(., clade_name = janitor::make_clean_names(clade_name)) %>%
  tibble::column_to_rownames(., var = "clade_name") %>%
  t() %>%
  as.data.frame() %>%
  tibble::rownames_to_column(., var = "subject_id")
metadata <- readr::read_csv("/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/dietML_microbe.csv")

subsetted_data <- merge(metadata, microbiome_data_for_omnibus, by = "subject_id") %>%
  dplyr::select(., dplyr::all_of(colnames(metadata)), dplyr::all_of(tmp))

write.csv(x = subsetted_data, file = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/subsetted_data.csv", append = F, quote = F, row.names = F)

## write run file
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

write.table(x = run_file_subsetted, file = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/input_for_ml_models/run_file_subsetted.txt", sep = "\t", row.names = F, append = F, quote = F)
