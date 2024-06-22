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