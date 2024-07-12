# General Workflow of the Pipeline

The pipeline designs to be evaluating $K$ ML, probabilistic, DL based methods over $J$ multiomics dataset, where each omics data is of dimension $M x Ni$.

For more information on how to run and execute the project on a remote setting, please look at the top level `README` at [here](../README.md)

To view tutorials on adding a new method to the pipeline please see [here](tutorials/README.md)

## Implementation

Each computational method has its very own software dependencies, hence a container is used to create isolated environment for each of them. It is locally built with docker, published to dockerhub, and pulled on HPC platform ARC Sockeye as apptainer container.


