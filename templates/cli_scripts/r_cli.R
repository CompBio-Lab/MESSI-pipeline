#!/usr/bin/env Rscript

# =============================================================================
# - The shebang line is required
# - You also need to make the script executable by chmod +x script_name.R
# - The script should be placed under method/resource/usr/bin
# - when wring the doc for docopt, DO NOT USE tab, use spaces
# =============================================================================
# This is a sample script in to run a multi-omics integration method 
# that is implemented in R. You should only be expecting inputs from the CLI
# parent process from Nextflow. And, output should be redirected either as 
# stdout (either cat or print) or directly write to scpace
# Author: Tony Liang
#
# Modifications required to the script could be:
# The Usage line to add required number of arguments of input
# The Options part to defined long versions and short alias for certain para
# And you should add brief description to each of those
# The --param=<name_here_doesnt_matter_too_much>
# But it should be defined in both Usage and Options
# Lastly, update the main function accordingly and codes inside it
# It should be well contained function that you could access it from outside
# by passing params only

# -----------------------------------------------------------------------
# ALERT
# -----------------------------------------------------------------------
# You need to use spaces for the 'doc' section in order to make docopt work
# it complains if using tab
# But rest code not from the doc, could use tab over space
# =============================================================================

doc <- "This is a sample script that does X, Y, Z. You should briefly 
give idea of what the script does. I.e. at least mention what params 
it expect, what is being called inside the script (library?) function? 
algorithm?. For more information read above's comments

Author: Tony Liang

Usage: 
  rcli.R [options]

Options:
  -p --path=<data_path> Path to read data
  -r --response=<y> Response variable
  -t --terms=<x> Terms to include as explanatory vars
"

# This is required to convert the doc (write meaningful doc)
# to a docopt object so that it's parsable (DELETE this line later)
opt <- docopt::docopt(doc)

# You should mainly be abstracting the codes inside here to a some function
# that takes certain number of arguments, and should do everything for you
# If it's to complicated, think of getting a processed data instead of raw
# data. Or any other things that could make this abstract enough but still
# clear enough by simply looking at it



# Roxygen styles should not be worried too much here, you should have a similar
# documentation in the start of the script
# Just briefly comment on special things to notice or annotations on dealing
# edge cases of the function
main <- function(data_path, response, terms) {
  data <- read.csv(data_path)
  f <- as.formula(paste0(response, " ~ ", terms))
  mod <- lm(f,data=data)
  print(coef(mod))
}

# This should not be deleted, and should be the only place that calls the func
# defined earlier to execute, any other codes should be made inside the function
main(
  data_path = opt[["--path"]], 
  response = opt[["--response"]],
  terms = opt[["--terms"]]
)