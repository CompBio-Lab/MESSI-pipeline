# General Workflow of the Pipeline

The pipeline designs to be evaluating $K$ ML, probabilistic, DL based methods over $J$ multiomics dataset, where each omics data is of dimension $M x Ni$.

For more information on how to run and execute the project on a remote setting, please look at the top level `README` at [here](../README.md)

## Implementation

Each computational method has its very own software dependencies, hence a container is used to create isolated environment for each of them. It is locally built with docker, published to dockerhub, and pulled on HPC platform ARC Sockeye as apptainer container.

Moreover, the data are locally stored and not tracked by GitHub. You could see some scripts under `modules/` to generate these data.

Note: due to platform-specific issue, places that stores these containers are separated than the place to launch the actual pipeline:

```bash
# The place that launches the pipeline
ls /scratch/st-singha53-1/tliang19/nxf_pipeline
# The place that store conatiners
ls /arc/project/st-singha53-1/tliang19/nxf_pipeline/apptainer_images
```

So, the pipeline should be run in the following way:
1. Launch the pipeline from `main.nf`
	+ It triggers two subworkflows in order, first the `Python()`, then the `R()`
2. The two subworkflows is then goint to call each of the method
	+ Whereas channels of data are supplied to the same method here as its input

### Simulation

**Current**:

- Method is defined in a nextflow process and argparser file in R/Python, these two would be in same directory:
	+ i.e. `../diablo/R_run_diablo.R` and `../diablo/R_diablo.nf`

---

**Previous**:

1. Create $m$ csvs to path 1 , path2 , ... path n
	+ Write a function to generate the csv content and write to file
	+ Note these data would then be replaced by actual multiomics data
	+ Maybe consider to write a nextflow process that handle's read data and distribute them to paths
2. Use a cli parser for reading these csvs per method
	+ This should be integrated with nextflow channels
3. Rewrite process input and output , since now channels of paths are expected for each process
	+ Include publishDir for method specific, try removing those within methods language specific code (R, Python)

