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
