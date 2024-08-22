# Save RDS by name of object (usually combined with lapply)

# Single savers ------------------------------------------
# CSV related


# savePred <- function(y_predicted_proba, filename="predicted_probabilities", 
#                      ext=".rds") {
#   
#   output_name <- paste0(filename, ext)
#   cat("\nSaving predictions to file\n")
#   saveRDS(y_predicted_proba, output_name)
#   cat("\nSaved predictions at", output_name, "\n")
# }

save_csv <- function(object, file, message, is_pred, ...) {
  cat("\nSaving object to csv\n")
  if (is_pred) {
    cat("\nSaving predictions to file\n")
    write.csv(object, file)
    cat("\nSaved predictions at", file, "\n")
  } else {
  
  
  if (is.list(object)) {
    lapply(names(object), function(obj_name) {
      sub_obj <- object[[obj_name]]
      ext <- paste0(".", tools::file_ext(file))
      if (is.list(sub_obj)) {
        lapply(names(sub_obj), function(sub_name) {
          filename <- paste0(sub_name, ext)
          f <- sub_obj[[sub_name]]
          # Keep as table no colnames
          # write.table(sub_obj[[sub_name]], filename,
          #             row.names = FALSE, col.names = FALSE)}
          # Keep as csv with colnames
          write.csv(sub_obj[[sub_name]], filename,
                    row.names = FALSE)
          cat("\nSaved", filename, "to file\n")
        }
        )
      } 
      # response variable
      else {
        df <- data.frame(response = sub_obj)
        filename <- paste0(name, "_", obj_name, ext)
        write.table(df, filename, col.names=FALSE,
                    row.names=FALSE)
      }
    })  
  }
  }
  write.csv(object, file, row.names = FALSE)
  cat("\nSaved", file, "to disk\n")
}

# rds related
save_rds <- function(object, file, message, ...) {
  cat("\nWriting", file, "to file\n")
  saveRDS(object, file=file)
  cat("\nFinished writing", file, "to file\n")
}


# General composite saver ----------------------------------------------------
# Source a python script as R object

# TODO: REMOVE THIS UGGLY FIX AND USE SOMETHING MORE STABLE
bin_dir <- Sys.getenv("PATH") |> 
    strsplit(":") |>
    unlist() |>
    tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)


save_bp <- here::here(pipeline_dir, "bin/savers")
reticulate::source_python(here::here(save_bp, "save_mudata.py"))
source(here::here(save_bp, "save_mae.R"))

# Big function goes here
saveFile <- function(
  object, name, prefix, output_format="",
  message="", is_pred=FALSE, ...){
  # Check format stuff
  is_rds <- grepl("rds", output_format)
  is_csv <- grepl("csv", output_format)
  is_mae <- grepl("mae", output_format, ignore.case = TRUE)
  is_mud <- grepl("mudata", output_format, ignore.case = TRUE)
  rds_or_csv = is_rds || is_csv
  mae_or_mud = is_mae || is_mud
  # RDS and CSV branch --------------------------------
  if (rds_or_csv) {
    file <- paste0(name, "." , output_format)
    if (is_rds) {
      save_rds(object=object, file=file, message=message, ...)
    }
    if (is_csv) {
      save_csv(
        object=object, file=file, 
        message=message, is_pred=is_pred, ...
        )
    }
  }
  
  if (mae_or_mud) {
    if (is_mae) {
      cat("\nSaving to MAE\n")
      output <- save_mae(object = object, name=name, prefix=prefix, message=message, ...) 
    }
    if (is_mud) {
      cat("\nSaving to MuData\n")
      var_names <- lapply(object$blocks, colnames)
      output <- save_mudata(object = object, name=name, message=message,
                            var_names=var_names)
    }
    cat("\nSaved to", name, "\n")
    cat("\nThe saved object is the following format:\n")
    return(output)
    } else {
    cat("\nNot implemented\n")
  }
}