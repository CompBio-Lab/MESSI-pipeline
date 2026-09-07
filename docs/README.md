# General Workflow of the Pipeline

The pipeline designs to be evaluating $K$ ML, probabilistic, DL based methods over $J$ multiomics dataset, where each omics data is of dimension $M x Ni$.

For more information on how to run and execute the project on a remote setting, please look at the top level `README` at [here](../README.md)

## Adding Methods to the Pipeline

To add a new multiomics integration method to the pipeline:

- **[Quick Reference](tutorials/adding_method_quick_reference.md)** - Fast checklist for adding a method
- **[Complete Guide](tutorials/adding_method_guide.md)** - Comprehensive documentation covering all steps
- **[R Method Tutorial](tutorials/adding_r-based_method/adding_r-based_method.md)** - Detailed example with logistic regression

Key topics covered:
- Creating Dockerfiles and containers
- Using the template generator in `bin/adding_method/`
- Implementing the four required processes (preprocess, train, predict, feature_selection)
- Writing binary scripts for R or Python
- Integration with CV_R or CV_PYTHON workflows

## Implementation

Each computational method has its very own software dependencies, hence a container is used to create isolated environment for each of them. It is locally built with docker, published to dockerhub, and pulled on HPC platform ARC Sockeye as apptainer container.


