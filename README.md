# Multiomics Experiments with SyStematic Interrogation (MESSI)

**Table of contents**:

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Setup the project](#setup)
4. [Running the pipeline](#running-the-pipeline)
5. [Result Inspection](#result-inspection)
5. [References](#reference)

## Overview

The **MESSI Pipeline** is a nextflow pipeline designed for benchmarking multiomics (genomics, proteomics, metabolomics) data integration methods. These methods are often implemented in R/Python, with the task of classification/regression, factor analysis, clustering and others.

## Project Structure

Some important locations:

- Shell scripts for setting up the project is located at `bin/`
- Main configuration for the pipeline is at `nextflow.config`. Other parameters, resources settings are found under `configs/`.
- Python and R source codes of methods are located in `modules/`
- Software environment definitions (containers) are under `containers/`
- `docs/` contain several demos and explanations of the pipeline usage and keynotes.
- High level abstraction of the flow of pipeline is found under `subworkflows/`. These often trigger codes under `modules/`
- Nextflow, R, and Python templates for method implementation could be found under `templates/`


## Setup

> [!NOTE]
> This pipeline have only tested under UBC ARC Sockeye's high performance cluster (SLURM), hence all instructions here might not apply to others.

The main software dependencies are the following:

**Requirements**:

- [Nextflow 22.10.7 or above](https://www.nextflow.io/)
- Bash `4.2.46`
- Java 11 (or later, up to 18), recommend using openJDK `11.0.18` 
- Docker/Apptainer `1.1.4` (formerly Singularity `3.8.5`)
- make `>= 3.82`
- git `>= 2.31.8`

Once you have these requirements setup, then you could clone the project with `git` in your desired place and
change the directory to the clone repo:

```bash
# This would unload the current modules that you are using (could be easily reverted)
module purge
# Then load relevant modules
module load gcc/9.4.0 git/2.31.8
# Choose a place you like to clone the repo, ideally the scratch space
git clone git@github.com:CompBio-Lab/MESSI-pipeline.git
# Then go into the directory of the repo
```

Then, create a `.env` file in the current directory and use the following template:

This is exactly what's inside `sample.env`, simply replace the file to `.env` using this command:

```bash
mv sample.env .env
```

Then edit the contents of the new `.env` file instead:

```bash
# You could also use vi or vim
nano .env
```

```bash
# ----------------------------------------------
# INSIDE THE .env file
# ----------------------------------------------
# The renamed file should not be tracked by git
# Important variables to replace the value
ALLOCATION_CODE=REPLACE # This should be the account to deduct computing resources usage
USER=REPLACE # This should be your cwl 
MAIL_USER=REPLACE # This should be the email to receive notification of the pipeline
```

For example the `.env` could be like the following:

```bash
# NOTICE there's no space between the `=` in VAR=VALUE 
ALLOCATION_CODE=st-myuser-123
USER=my_cwl_username
MAIL_USER=dummy_name@gmail.com
```

> [!Warning]
> Make sure you do not track this .env file onto git

Then, you could start to setup the required apptainer images (This could take a while to run, better to hang it in a `tmux`/`screen` session) for the pipeline by the following command:

```bash
# Run this command under the this same pipeline root dir
make setup
```
> [!TIP]
> If you see an error of `no space left`, this is due to the apptainer cache that it creates in your home dir, which you could clean it by the following command:
>
> `rm -r ~/.apptainer/cache`

Then, you could resume the setup command after have encountered and solved the `no space error`:

```bash
make setup
```

Once you see the log:
```bash
Finished setting up environment
```
This means all required images have successfully downlaoded and stored under `/arc/project/<ALLOCATION_CODE>/<USER>/MESSI-apptainer-images`

### Data Source

Given ARC Sockeye have no internet connection on compute nodes, which means user cannot pull data during the pipeline computation. Hence, the data have pre-stored in a common directory.

### Running the pipeline

Lastly, you could start the pipeline by submitting the wrapper script that sends the batch script to SLURM:

```bash
# If you see any complains from this script, then is likely you did not setup properly
# NOTE: this only works on the UBC ARC Sockeye platform for now
bash launcher_sockeye.sh
```

## Result inspection

For viewing the log of current runtime status of the pipeline, you could check the latest `MESSI-main-<job-id>.log` file in the root dir of the repo:

```bash
# <job id> is the one generated from SLURM
# Usually numeric, for example 1234567 is a job id here:
cat MESSI-main-1234567.log
```

In order to see the results of the pipeline, you could inspect the final results in this directory as it progresses using this command:

```bash
# Assuming you are in the root dir of the repo
ls MESSI_results
```

The directory structure of the `MESSI_results/` should be like the following once the pipeline have completed:

```bash
MESSI_results
```


There's option to change this default directory by changing the `OUTDIR` param in the `launch_MESSI_pipeline.sh` script:

```bash
# It is possible to use a for loop in the bash script to pass multiple OUTDIR and run as a monte carlo cross validation
OUTDIR=another_directory_that_you_like
```


## License

This project is licensed under the [MIT License](LICENSE)

## Reference

Bredikhin, Danila, Ilia Kats, and Oliver Stegle. 2022. “MUON: Multimodal Omics Analysis Framework.” Genome Biology 23 (1): 42.

Di Tommaso, Paolo, Maria Chatzou, Evan W Floden, Pablo Prieto Barja, Emilio Palumbo, and Cedric Notredame. 2017. “Nextflow Enables Reproducible Computational Workflows.” Nature Biotechnology 35 (4): 316–19.

Ding, Daisy Yi, Shuangning Li, Balasubramanian Narasimhan, and Robert Tibshirani. 2022. “Cooperative Learning for Multiview Analysis.” Proceedings of the National Academy of Sciences 119 (38): e2202113119.

Jeong, Dabin, Bonil Koo, Minsik Oh, Tae-Bum Kim, and Sun Kim. 2023. “GOAT: Gene-Level Biomarker Discovery from Multi-Omics Data Using Graph ATtention Neural Network for Eosinophilic Asthma Subtype.” Bioinformatics, btad582.

Kurtzer, Gregory M, Vanessa Sochat, and Michael W Bauer. 2017. “Singularity: Scientific Containers for Mobility of Compute.” PloS One 12 (5): e0177459.

Singh, Amrit, Casey P Shannon, Benoı̂t Gautier, Florian Rohart, Michaël Vacher, Scott J Tebbutt, and Kim-Anh Lê Cao. 2019. “DIABLO: An Integrative Approach for Identifying Key Molecular Drivers from Multi-Omics Assays.” Bioinformatics 35 (17): 3055–62.

UBC Advanced Research Computing. 2019. “UBC ARC Sockeye.” UBC Advanced Research Computing. https://doi.org/10.14288/SOCKEYE.

Wang, T., Shao, W., Huang, Z. et al. MOGONET integrates multi-omics data using graph convolutional networks allowing patient classification and biomarker identification. Nat Commun 12, 3445 (2021). 




