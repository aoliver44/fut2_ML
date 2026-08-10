## average out the feature importance using signed SHAP - post subset

## load libraries
library(dplyr)
library(ggplot2)
`%!in%` = Negate(`%in%`)
options(warn=-1)

## source avg shap rank commands
source("/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/scripts/average_shap_ranks.R")

rf_subsetted <- create_omnibus_data(input_dir = "/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs", response = "secretor_status_subsetted", model = "rf", feature_pattern_start = "^k_", sv_object = "full")
## load full data that has been pre-processed
attach("/quobyte/dglemaygrp/aoliver/yasmine/fut2_analysis_09032026/taxahfe_ml_outputs/secretor_status_subsetted/rf/output_131465/ml_analysis/shap_inputs_dietml_131465.RData", warn.conflicts = FALSE)
feature_of_interest <- split_from_data_frame$data %>% dplyr::select(., subject_id, feature_of_interest)
correlation_response <- cbind(feature_of_interest, shap_data_full)
correlation_response <- correlation_response %>%
  dplyr::mutate(., feature_of_interest = ifelse(feature_of_interest == "secretor", 1, 0)) %>%
  correlation::correlation(method = "spearman") %>% 
  dplyr::filter(., grepl("feature_of_interest", Parameter1) | grepl("feature_of_interest", Parameter2)) %>%
  dplyr::mutate(., abs_cor = ifelse(rho < 0, -1, 1)) %>%
  dplyr::select(., Parameter2, abs_cor)
signed_shap <- merge(secretor_status_subsetted_rf_raw_ranks, correlation_response, by.x = "feature", by.y = "Parameter2")
signed_shap <- signed_shap %>% dplyr::mutate(., signed_shap = (mean_shap * abs_cor))
signed_shap_plot <- signed_shap %>%
  dplyr::filter(., overall_rank_mean < 11) %>%
  ggplot() + aes(x = reorder(feature, signed_shap), weight = as.numeric(signed_shap)) +
  geom_bar(aes(fill = signed_shap)) +
  coord_flip() +
  scale_fill_gradientn(colors = NatParksPalettes::natparks.pals("Glacier",n=30,type="continuous")) +
  labs(x = "", y = "Mean Signed Shap Value") +
  theme_bw(base_size = 14) + theme(text = element_text(colour = "black"), axis.text = element_text(colour = "black"))
detach()
