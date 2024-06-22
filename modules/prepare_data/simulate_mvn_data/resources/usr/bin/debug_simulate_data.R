#!/usr/bin/env Rscript

# Doc section --------------------------------------------------------------
'This is the script to simulate data with X block , Z block, and a response 
vector R. The output is a list in R. By default it writes the rds file 
to current directory.

Author: Tony Liang

Usage:
  simulate_data.R [options]
    
Options:
  -n N --number=N           Number of observations [default: 200]
  --num_predictors=P        Number of predictors to use [default: 500]
  -m M --block_num=M        Number of blocks to generate [default: 3]
  --latent_predictors=IMP   Number of latent predictors [default: 30]
  -s SIGMA --sigma=SIGMA    Noise strength to add into response [default: 39]
  --sy=SY                   Standard deviation of Y [default: 1]
  --sp=SP                   Standard deviation of block components [default: 3]
  --u_std=U_STD             Standard deviation of normal distributed U [default: 1]
  --ft_str=FCT_STR          Factor strength [default: 7] 
  --task=TASK               Type of response, continous/binary/categorical [default: continous]
  --tr=TRANSFORM            Transformation on response, one of sigmoid or softmax [default: sigmoid]
  --output_format=OUT_FMT   Type of output data to write. One of MAE or MuData [default: MAE]
	--name=NAME								Name of data to save [default: sim_data]
' -> doc
cat("\nThis is the chr ver\n")
opt_chr <- docopt::docopt(doc)
print(opt_chr)
cat("\nThis is the num ver\n")
opt <- lapply(opt_chr, function(x) ifelse(grepl("^\\d+\\.?\\d*$", x), 
                                          as.numeric(x), x))
print(opt)
#==============================================================================

# number <- n <- 200
# num_predictors <- p <- 300
# m <- blocks_num <- 3
# p_imp <- latent_predictors <- 30
# sigma <- 39
# sy <- 1
# sp <- 3
# u_std <- 1
# ft_str <- factor_strength <- 7
# #task <- c("continous", "binary", "categorical")
# task <- "binary"
# tr <- "sigmoid"
# #tr <- c("sigmoid", "softmax")
# name <- prefix <- "sim_data"
# output_format <- "rds"



# library(magrittr)
# # Parse above doc
# opt_chr <- docopt::docopt(doc)
# # Source common helpers
# source(here::here("modules/R/generic_helpers.R"))
# load_helpers(helper_path = "modules/R/simulate_data/helpers/")
# # Convert all options to numeric
# opt <- lapply(opt_chr, function(x) ifelse(grepl("^\\d+\\.?\\d*$", x), 
#                                           as.numeric(x), x))

# # Generating process of data

# # TODO: consider add another block of "omics", so another matrix
# # TODO: consider combining the px , pz and possibly the extra block to same "base" number of features
# #       such that px = base + c1 , pz = base + c2 , pw = base + c3 
# # TODO: Now same thing happens with sy, sx, sz, so all needs to be fixed

# number <- n <- 200
# num_predictors <- p <- 500
# p_imp <- 30
# sigma <- 39
# sy <- 1
# sx <- sz <- sw <- 3
# u_std <- 1
# ft_str <- factor_strength <- 7
# task <- c("continous", "binary", "categorical")
# tr <- c("sigmoid", "softmax")
# name <- prefix <- "sim_data"

# simulate_data <- function(n, p, p_imp, sigma,
#                           sy, sx, sz, sw,u_std, ft_str,
#                           task = c("continous","binary", "categorical"),
#                           tr=c("sigmoid", "softmax"), 
#                           output_format=c("mae", "mudata", "csv", "rds"),
#                           threshold=0.5) {
#   # Match arguments
#   task <- match.arg(task)
#   tr <- match.arg(tr)
#   output_format <- match.arg(output_format)
#   # get predictors
#   num_ps <- getNumPredictors(p = p, ft_str = ft_str, sigma=sigma)
#   px <- num_ps$px
#   pz <- num_ps$pz
#   pw <- num_ps$pw
#   args_used <- c(as.list(environment()))
#   logging_params(args_used) # custom function to format and log
#   # Record time to track execution time
#   start_time <- Sys.time()
  
#   # Check p_imp not greater than any of px or pz
#   if ( p_imp > max(px, pz, pw)) {
#     print("p_imp cannot be > px or pz or pz, using default: 30")
#     p_imp <- 30
#   }
#   # Simulate data based on the factor model
#   x = matrix(rnorm(n*px), n, px)
#   z = matrix(rnorm(n*pz), n, pz)
#   w = matrix(rnorm(n*pw), n, pw)
#   U = matrix(rep(0, n*p_imp), n, p_imp)
  
#   # Relate matrices by u 
#   for (m in seq(p_imp)){
#     u = rnorm(n, sd = u_std)
#     x[, m] = x[, m] + sx*u
#     z[, m] = z[, m] + sz*u
#     w[, m] = w[, m] + sw*u
#     U[, m] = U[, m] + sy*u
    
#   }
#   # Center and not scale these accordingly
#   x = scale(x, center=TRUE, scale=FALSE)
#   z = scale(z, center=TRUE, scale=FALSE)
#   w = scale(w, center=TRUE, scale=FALSE)
  
#   # Assign column names to use 1 ... n 
#   colnames(x) = paste0("x", 1:ncol(x))
#   colnames(z) = paste0("z", 1:ncol(z))
#   colnames(w) = paste0("w", 1:ncol(w))
  
#   # Assign rownames to be some string
#   common_rows = 1:nrow(x)
#   rownames(x) <- rownames(z) <- rownames(w) <- paste0("pat-", common_rows)
  
#   # Create beta matrix and Y
#   beta_U = c(rep(ft_str, p_imp))
#   mu_all = U %*% beta_U
#   y <- mu_all + sigma * rnorm(n)
#   # Convert y to suitable outcome with user-transformation
#   #tr <- match.arg(tr)
#   threshold = 0.5
#   y_temp <-  y %>%
#     transformation(tr=tr) %>%
#     (function(y) ifelse(y < threshold, "no", "yes")) %>%
#     factor(levels = c("no", "yes"))
#   # task <- match.arg(task)
#   if (tolower(task) == "binary") {
#     y <- y_temp  %>%
#       as.integer() - 1
#   }
  
#   if (tolower(task) == "categorical") {
#     y <- y_temp 
#   }
  
#   elapsed <- Sys.time() - start_time
#   cat("\nTime taken to simulate data:", round(elapsed, 6), "seconds\n")
#   cat("\nData simulated!\n")
#   return(dat=list(blocks = list(x=x, z=z, w=w), response=y))
# }

# main <- function(number, num_predictors, p_imp, 
#                   sigma, sy, sx, sz, sw, u_std, 
#                   factor_strength, task, tr, output_format,
#                  name="sim_data", prefix="sim_data") {
  
#   cat("Generating simulation... \n")
#   # Invoke simulate data
  
#   dat <- simulate_data(n=number, p=num_predictors, 
#                         p_imp=p_imp, sigma=sigma, sy = sy, sx=sx, sz=sz, sw=sw, 
#                         u_std=u_std, ft_str=factor_strength, task=task,tr=tr,
#                        output_format=output_format)
#   # Time to write data
#   write_start <- Sys.time()
#   #cat("\nWriting to disk\n")
#   #lapply(names(dat), function(name) saveFile(object=dat[[name]], 
#   #                                            name=name))
#   # -------------------------------------
#   # To MAE or MuData
#   saveFile(dat, name = name, output_format=output_format, prefix=prefix)
  
#   logging_write_disk(write_start = write_start)
#   # Write metadata to file as well
#   return(dat)
# }

# # Set seed to guarantee reproducible result (DELETE Later)
# set.seed(329)

# dat <- main(number = opt$number, num_predictors   =  opt$num_predictors,
#             p_imp  = opt$latent_predictors, sigma =  opt$sigma,
#             sy = opt$sy, sx = opt$sx, sz = opt$sz, sw = opt$sw,
#             u_std = opt$u_std, factor_strength =   opt$ft_str,
#             task = opt_chr$task, tr=opt_chr$tr, output_format=opt$output_format
#             )



