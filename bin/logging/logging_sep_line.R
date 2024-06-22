# Fun to log a separator line of special character
logging_sep_line <- function(char="=",sep_n=75) {
  cat(paste(rep(char, sep_n), collapse=""), "\n")
}