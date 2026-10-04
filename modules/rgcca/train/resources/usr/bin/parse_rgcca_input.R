# Use this function to parse an mae and get the
# desired format to input for rgcca
# 
# It requires this format:
# List(m1=m1, m2=m2, m3=m3, ... , mn=mn, response=response)
# Whereas the response is in a same list of the blocks (m_i)
# And to make life easier, response is always put at the n-th position
# So we gonna extra that X and Y and recombine it in a new list
parse_rgcca_input <- function(merged_list, outcome_type="classification") {
  blocks_list <- merged_list$X
  if (outcome_type == "survival") {
    return(blocks_list)
  } else if (outcome_type == "classification") {
    blocks_list[["response"]] <- merged_list$Y
    return(blocks_list)

  }  else {
    stop("outcome_type must be either classification or survival")
  }
}