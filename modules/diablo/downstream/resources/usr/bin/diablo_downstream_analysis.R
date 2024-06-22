#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run DIABLO method from mixOmics package,
make various EDA plots to visualize sample or variables and their loadings

Usage:
  diablo_downstream_analysis.R [options]

Options:
  --mae_path=MAE_PATH       Path to read full mae data
  --dataset_name=DNAME      Name of the dataset
  --height=HEIGHT           Height of figure [default: 8]
  --width=WIDTH             Width of figure [default: 8]
  --resolution=RESOLUTION   Resolution of figure [default: 1000]
  --units=UNITS             Units of the figure dim [default: in]
  --device=DEVICE           Graphic device svg or png [default: svg]
  --makePlot                Make plots or not [default: true]
  --prefix=PREFIX           Prefix to read HDF5 [default: pre]
"

library(here)
library(mixOmics)
library(magrittr)
library(dplyr)
# Parse docopt
opt <- docopt::docopt(doc)
# Source custom scripts
source(here("bin/misc_utils/extract_Xy.R"))
source(here("bin/misc_utils/load_MAE.R"))

# Fun to create empty graphic device of fixed size provided
getPlotDevice <- function(name, dataset_name, height, width, res, 
                         units, device) {
  plot_name <- paste0(dataset_name, "-", name)
  if (device == "svg") {
    filename <- paste0(plot_name, ".svg")
    return(svg(filename,
        height=height,
        width=width))
  }
  
  if (device == "png") {
    filename <- paste0(plot_name, ".png")
    return(png(filename,
        height = height,
        width = width,
        res=res,
        units=units))
  }
  
  return(device)
    
}

main <- function(mae_path, dataset_name, height, width,
                 res, units, device, makePlot) {
  if (!makePlot) {
    return("Non of the plots will be generated")
  } 
  else {
    data <- load_MAE(path = mae_path) |> extract_Xy()
    #  a lots of plot to generate here
    model <- block.splsda(X = data$X, data$Y)
    # =================================================
    # Theres isnt really a good way to plot these 
    # baseR plots devices non-interactively, thats why
    # you would see a lot of repetitive code here
    # TODO: need to add those parts of ggplot
    # The ggplot2 save function should be much simpler
    # =================================================
    
    # These plots are all default exported to svg
    # Visualization of samples
    # Correlation and circle plot of samples
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "correlation_circle_plot", dataset_name=dataset_name, 
    height=height, width=width, res=res, units=units, device=device)
    plotDiablo(model)
    dev.off()
    # Individual samples for each block
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "individual_samples_plot", dataset_name=dataset_name,
    height=height, width=width, res=res, units=units, device=device)
    plotIndiv(model)
    dev.off()
    # Arrow plot, shows all blocks
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "block_samples_arrow_plot", dataset_name=dataset_name,
    height=height, width=width, res=res, units=units, device=device)
    plotArrow(model)
    dev.off()
  
    # Functions to visualise variables: 
    #   -------------------- 
    #   plotVar, plotLoadings, network, circosPlot 
    # Correlation circle of features in each block
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "variables_correlation_circle_plot", dataset_name=dataset_name,
    height=height, width=width, res=res, units=units, device=device)
    plotVar(model)
    dev.off()
    # PCA Loadings of variables
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "variables_loadings_plot", dataset_name=dataset_name,
    height=height, width=width, res=res, units=units, device=device)
    plotLoadings(model)
    dev.off()
  }
}
# Execute the function here
main(mae_path=opt$mae_path, 
     dataset_name=opt$dataset_name,
     height=as.numeric(opt$height), 
     width=as.numeric(opt$width), 
     res=as.numeric(opt$res),
     units=opt$units, 
     device=opt$device, 
     makePlot=opt$makePlot
)
