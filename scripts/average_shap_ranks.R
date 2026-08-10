## average out the feature importance using signed SHAP

## load libraries
library(dplyr)
library(ggplot2)
`%!in%` = Negate(`%in%`)
options(warn=-1)

## example command
# tmp <- create_omnibus_data(input_dir = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs", response = "secretor_status", model = "rf", feature_pattern_start = "^k_", sv_object = "train")
## create a function to loop over directories and return top features
create_omnibus_data <- function(input_dir, response, model, feature_pattern_start, sv_object = "train") {
  
  print(paste0("Working on: ", paste0(input_dir, "/", response, "/"), " | model: ", model))
  ## set working directory
  working_path <- paste0(input_dir, "/", response, "/", model, "/")
  setwd(working_path)
  
  ## loop over .RData files
  raw_ranks <- data.frame(feature=factor())
  raw_means <- data.frame(feature=factor())
  
  ## get metric specific RData files
  rdata_files <- list.files(path = working_path, pattern = "*.RData", full.names = T, recursive = T)
  
  ## initate progress bar
  pb <- progress::progress_bar$new(total = 20)
  
  ## check if rdata file exists, otherwise skip
  for (rdata_file in seq(1:length(rdata_files))) {
    if (!file.exists(rdata_files[rdata_file])) {
      next()
    }
    attach(rdata_files[rdata_file], warn.conflicts = FALSE)
    
    ## check if shap sv_train object exists in rdata file, otherwise skip
    if (sv_object == "train") {
      if (exists("sv_train")) {
        sv_obj_saved <- sv_train; detach()
      } else {
        detach()
        next()
      }
    }
    
    if (sv_object == "full") {
      if (exists("sv_full")) {
        sv_obj_saved <- sv_full; detach()
      } else {
        detach()
        next()
      }
    }
    
    ## report progress
    pb$tick()
    Sys.sleep(1 / 100)
    
    ## track seed name so rdata results are seperate
    seed_name <- strsplit(rdata_files[rdata_file], split = "/")[[1]][13]
    #seed_name <- strsplit(rdata_files[rdata_file], split = "/")[[1]][11]
    
    ## read sv_train and sort by mean abs shap value
    top_training_features <- as.data.frame(sort(colMeans(abs(sv_obj_saved$S)), decreasing = T)) %>%
      tibble::rownames_to_column(., var = "feature") %>%
      dplyr::rename(., "shap_value" = 2)
    rm(sv_obj_saved)
    ## rank based on shap value
    top_training_features_ranks <- top_training_features %>%
      dplyr::mutate(., {{seed_name}} := as.numeric(as.factor(-shap_value))) %>%
      dplyr::select(., -shap_value)
    raw_ranks <- merge(top_training_features_ranks, raw_ranks, by = "feature", all = T)
    ## means based on shap value
    top_training_features_means <- top_training_features %>%
      dplyr::mutate(., {{seed_name}} := shap_value) %>%
      dplyr::select(., -shap_value)
    raw_means <- merge(top_training_features_means, raw_means, by = "feature", all = T)
  }
  
  ## first calculate a presence rate, how often a feature is seen in a model
  presence <- raw_ranks %>%
    tidyr::pivot_longer(-feature, names_to = "run", values_to = "rank") %>%
    dplyr::group_by(feature) %>%
    dplyr::summarise(presence_rate = mean(!is.na(rank)), n_runs_present = sum(!is.na(rank)))
  
  ## assign any rows that are NA (feature in one dataset but not the others)
  ## last place (low rank)
  raw_ranks[is.na(raw_ranks)] <- nrow(raw_ranks)
  
  ## average ranks across the features
  raw_ranks_averaged <- raw_ranks %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      mean_rank = mean(c_across(where(is.numeric)), na.rm = TRUE),
      median_rank = median(c_across(where(is.numeric)), na.rm = TRUE)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      overall_rank_mean = rank(mean_rank, na.last = "keep", ties.method = "average"),
      overall_rank_median = rank(median_rank, na.last = "keep", ties.method = "average")
    ) %>%
    dplyr::relocate(., feature, mean_rank, median_rank, overall_rank_mean, overall_rank_median)
  
  ## average shap across the features
  raw_shap_averaged <- raw_means %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      mean_shap = mean(c_across(where(is.numeric)), na.rm = TRUE),
      median_shap = median(c_across(where(is.numeric)), na.rm = TRUE)
    ) %>%
    dplyr::relocate(., feature, mean_shap, median_shap)
  
  ## merge raw_shap_averaged with raw_ranks_averaged
  raw_ranks_averaged <- merge(raw_ranks_averaged, raw_shap_averaged, by = "feature") %>%
    merge(., presence, by = "feature")
  ## create final file
  
  raw_rank_final <- raw_ranks_averaged %>%
    dplyr::select(., feature, overall_rank_mean, overall_rank_median, mean_rank, median_rank, mean_shap, median_shap, presence_rate) %>%
    dplyr::mutate(at_median_ceiling = median_rank == nrow(raw_ranks_averaged)) %>%
    dplyr::mutate(mean_median_gap = median_rank - mean_rank)
  
  ## define gap using logic
  threshold <- raw_rank_final %>%
    dplyr::filter(presence_rate == 1) %>%
    dplyr::summarise(gap_p95 = quantile(abs(mean_median_gap), 0.95, na.rm = TRUE)) %>%
    dplyr::pull(gap_p95)
  
  raw_rank_final <- raw_rank_final %>%
    dplyr::mutate(
      stability_flag = case_when(
        presence_rate >= 0.9 & abs(mean_median_gap) < threshold ~ "stable_core",
        presence_rate >= 0.9 & abs(mean_median_gap) >= threshold ~ "stable_presence_unstable_rank",
        at_median_ceiling & mean_median_gap > threshold           ~ "occasional_spike",
        at_median_ceiling                                          ~ "rare_low_impact",
        TRUE                                                        ~ "intermittent"
      )
      # stable_core — present almost always, rank barely moves
      # stable_presence_unstable_rank — present almost always, but rank swings a lot between runs (worth investigating — could be seed-dependent interactions with another feature)
      # occasional_spike — mostly absent, but strong when present
      # rare_low_impact — mostly absent, and unremarkable when present
      # intermittent — present in a moderate share of runs (roughly 50–90%), not cleanly describable as either "core" or "occasional"
    )
  ## save in case we want to plot
  assign(x = paste0(response, "_", model, "_raw_ranks"), value = raw_rank_final, envir = .GlobalEnv)
  
  ## only take features, which are not part of the core covariates but still
  ## show up in the top 10 features by shap for each data domain
  new_features <- raw_rank_final %>%
    dplyr::arrange(., overall_rank_mean) %>%
    dplyr::filter(., grepl(feature_pattern_start, feature)) %>%
    dplyr::slice_head(., n = 10) %>%
    dplyr::pull(., feature)
  
  return(new_features)
}