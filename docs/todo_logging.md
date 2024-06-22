# TODO

This is file to track things that needs to be solved/improved, consider turning this to issue.

## Updates and Todos

### Latest

- Rebuild all images and push to dockerhub
	+ Add a script to rebuild for all files in `./containers/dockerfiles`
- Rename modules names from Python/R to classification/others, need to fix import issues in files
- Make `./minimal.nf` clearer to show the minimal setting of running it
- Implement CLI for cooperative learning
	+ Update its image
		- Have MAE available
		- Publish it to dockerhub and update at ARC
	+ Test with GSE71669
- Implement CLI for MOGONET
	+ Update its image
		- Have MuData available
		- Publish it to dockerhub and update at ARC
	+ Test with GSE71669
- Implement CVs for all methods
-


### Upcoming

- Rephrase the documentation in [docs/README](./README.md)
- This is a good source to implement the rest of methods or workflows (although bit different), see [here](https://github.com/nextflow-io/hyperopt/blob/master/main.nf)
- Overlap of check installation in `Makefile`, `bin/install.sh` and `bin/0*.sh`
- Turn some env definitions to params instead in either of `nextflow.config` or `configs/pbs_remote.config`
- The `max_memory/cpus/time` are not being used when directly using `clusterOptions` with `-l` syntax
	+ See `pbs_remote.config`
- Update singularity to apptainer in the configurations
- Need to update the `02-pull_all_containers.sh`, so that it should still execute if any updates to the image were being made
	+ ~~Will do manually for now, leave it for later~~
	+ The --force option is not quite robust, need more testing or simply remove exisiting sif, then pull
- Update ALLOC option, more robust way on the setup in case it has different allocation code
	+ See it in remote_config
	+ See it in install_conda_nxf
	+ See it in conda_nxf.sh (the pbs script)

- Ignore or not ignore results, need something to show on github. But it takes memories to store, since most are html and txts
	+ Makefile could provide an alternative to manually save a log on sockeye but not github

- Good thing with docopt is, you could use both:
```bash
### Using the example of sample script
Rscript sample_script.R -p a.csv -r y -t x1+x2
###
Rscript sample_script.R --path=a.csv --response=y --terms=x1+x2
```

---

## Finished

### Setup

- ~~Using conda's nextflow solves problem of downloading full size binary of nextflow, but requires additional step to setup it~~
	+ ~~Plus, you need to follow some steps to do that~~

- ~~Nextflow version has to be at least of this `NXF_VER=22.11.0-edge` to fully support apptainer containers~~

- ~~Remember to `module load apptainer` prior to load stuff~~

- ~~Have option to run as following:~~
	+ ~~Minimal setting, run the full pipeline from top to bottom but with **MINIMAL** data~~
	+ ~~Full setting, normal run as all full pipeline~~
	+ ~~Test setting, only run the testWorkflow to check paths and etc.~~

## Run

- ~~Make a template R script file that defines generic cli parser and required arguments for future methods~~
- ~~Make cooperative_learning use docopt as well to adapt cli arguments~~
- ~~Use more of publishDir from nextflow (make it as a param), and not having to to this in the modules script specifically~~
- ~~Ask what do to when loaded ALL case data, where you could have NAs in the Y component~~

## To Read

[Include Statements](https://github.com/nextflow-io/nextflow/issues/1851)



