library(dplyr)

scores <- readr::read_delim(file = "/home/rstudio/taxahfe_ml_outputs/tmp_scores_08_17_26.txt",
                            col_names = c("response", "program", "model", "seed", "bal_acc_test", "bal_acc_train"),
                            num_threads = 6, delim = " ")

scores %>% dplyr::group_by(., response, model) %>%
  dplyr::summarise(., mean_bal_test = mean(bal_acc_test), 
                   mean_bal_train = mean(bal_acc_train), sd_test=sd(bal_acc_test), sd_train=sd(bal_acc_train),
                   max_bal_acc=max(bal_acc_test)) %>% filter(., grepl("rf", model))
