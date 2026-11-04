# Adding a method to MESSI

You write three functions in one file. A small command generates everything else and wires it into the pipeline. You write no Nextflow and no file I/O, and you need to know nothing about MultiAssayExperiment or MuData.

Scope: binary classification, in R or Python. A generated method is skipped when `outcome_type` is `survival`.

## 5-minute quick start

Run these from the top folder of the repository. Python 3.6 or newer is enough for the command, with no packages to install. If `python` is not Python 3 on your system, type `python3`.

```bash
# 1. Generate a method. Asks one question at a time.
python bin/adding_method/add_method.py

# 2. Open the one file it names, modules/<method>/resources/usr/bin/<method>_core.R (or .py),
#    and fill in fit, predict_proba and feature_weights.

# 3. Self-check on synthetic data: no Nextflow, no containers.
python bin/adding_method/add_method.py check <method>

# 4. Does the container qualify? Runs your functions inside it. Needs Docker.
python bin/adding_method/add_method.py check-image <method>

# 5. Run only this method through the real pipeline on the small rosmap dataset.
#    Needs Docker only. Uses your nextflow if you have one, otherwise Nextflow in a container,
#    so it works on Windows, Mac and Linux. It prints the exact nextflow run command first.
python bin/adding_method/add_method.py test <method>
```

Want to see it work first? Generate the worked example, logistic regression on all views joined together, and go straight to step 3:

```bash
python bin/adding_method/add_method.py --method logistic_r --language R --container rgcca --example logistic --yes
python bin/adding_method/add_method.py --method logistic_py --language Python --container eipy --example logistic --yes
```

`make add_method` does the same as step 1. It passes on `METHOD=`, `LANGUAGE=`, `CONTAINER=`, `EXAMPLE=`, `YES=1` and `DRY_RUN=1`, and `PYTHON=python` selects the interpreter.

### What the questions look like

```text
Add a method to MESSI. Press Enter to accept the value in [brackets].

Step 1 of 3: method name
  Used for the module folder, the process names and the skip_<name> parameter.
  Lowercase letters, digits and underscores.
Method name [my_method]: rgcca
  Not usable: A method or module called 'rgcca' already exists. Choose another name.
Method name [my_method]: my_logit

Step 2 of 3: language
  The language you will write the three functions in.
Language (R or Python) [R]:

Step 3 of 3: container
  Every step of your method runs inside one container image, so the image must
  have the packages your code uses. Nothing to install? Reuse an existing image.
  1) reuse tonyliang19/rgcca:latest
  2) reuse tonyliang19/caret_multimodal:latest
  3) reuse tonyliang19/mofa:latest
  4) new: generate a Dockerfile FROM tonyliang19/r_method_base_dev that you build and push
Choice (number, or a full image name) [1]:

Method 'my_logit' in R, container tonyliang19/rgcca:latest

Files to create:
  modules/my_logit/main.nf
  modules/my_logit/resources/usr/bin/messi_contract.R
  modules/my_logit/resources/usr/bin/messi_run.R
  modules/my_logit/resources/usr/bin/my_logit_core.R
  subworkflows/methods/my_logit/main.nf

Files to modify:
  nextflow.config
  subworkflows/cross_validation/main.nf
  subworkflows/cross_validation/r/main.nf
  subworkflows/feature_selection/main.nf

Write these files? (y/n) [y]:
```

It then prints the numbered next steps, with the exact commands for your method.

Every question has a flag, for scripts: `--method`, `--language`, `--container`, `--yes` to skip the questions, and `--dry-run` to show the plan and write nothing. Names are checked, and an existing method is never overwritten.

## What the command creates and changes

Created:

| File | Purpose | Edit it? |
| --- | --- | --- |
| `modules/<method>/resources/usr/bin/<method>_core.{R,py}` | your three functions | **yes, only this one** |
| `modules/<method>/resources/usr/bin/messi_run.{R,py}` | loads data and folds, calls your functions, saves and writes everything | no |
| `modules/<method>/resources/usr/bin/messi_contract.{R,py}` | the validators below | no |
| `modules/<method>/main.nf` | the processes `<METHOD>_PREPROCESS`, `_TRAIN`, `_PREDICT` and `_SELECT_FEATURE` | no |
| `subworkflows/methods/<method>/main.nf` | runs cross validation for this method | no |
| `containers/dockerfiles/<method>.Dockerfile` | only if you chose a new container | add your packages |

Changed, at the `// add_method:...` marker comments, which you should keep:

| File | What is added |
| --- | --- |
| `nextflow.config` | `skip_<method> = false`, and `withLabel: <method> { container = '<image>' }` |
| `subworkflows/cross_validation/main.nf` | the method's name, in the list that `shouldRunR()` or `shouldRunPython()` checks |
| `subworkflows/cross_validation/{r,python}/main.nf` | the include, the skip line, the call and the merge |
| `subworkflows/feature_selection/main.nf` | the include, the skip line, the call and both merges |

The command prints every line it inserts, grouped by file and counted, so you see the exact change before it is written. `--dry-run` prints the same preview and writes nothing.

**A new method runs by default.** That includes later runs of the full pipeline, so a method whose functions are still blank makes those runs fail. Add `--skip_<method> true` to leave it out.

**Classification only, for now.** The skip line that is inserted reads `skip_<method> = params.skip_<method> || outcome_type != 'classification'`. A generated method therefore runs only on a classification dataset; on a survival dataset it is skipped silently, with no error. The worked examples are classification. To support another outcome type, change that condition by hand in the two subworkflow files.

To undo before committing: `git checkout -- nextflow.config subworkflows/cross_validation subworkflows/feature_selection`, then delete `modules/<method>`, `subworkflows/methods/<method>` and any new Dockerfile.

## The three functions

The stubs in the generated file show all of this, with a minimal example that works.

| Function | Input | Must return |
| --- | --- | --- |
| `fit(X_train, y_train, ...)` | `X_train`: one samples x features matrix per view (see below). `y_train`: 0/1 labels, where 1 is the positive class. Also `seed`, already applied. | any object. It is saved with `saveRDS` or `pickle`, so it must survive that. |
| `predict_proba(model, X_test)` | the object from `fit`, and test data shaped like `X_train` | a numeric vector of the probability of class 1, one per test sample, in the same order |
| `feature_weights(model)` | the object from `fit`, fitted on all samples | a table with columns `feature`, `view`, `coef` |

| | R | Python |
| --- | --- | --- |
| `X_train`, `X_test` | named list of numeric matrices with row names (samples) and column names (features) | dict of pandas DataFrames, with sample names in the index and feature names in the columns |
| `y_train` | integer vector named by sample | 1-D numpy integer array |
| table returned by `feature_weights` | `data.frame` | pandas `DataFrame` |

Samples are in the same order in every view. Any preparation, such as scaling, belongs inside `fit` and `predict_proba`. To record settings in the hyperparameter output, optionally set the constant `HYPERPARAMETERS` at the top of the file; the stub explains how. Say honestly how a value was chosen: `tuned`, `fixed`, `default` or `data-derived`. The wrappers set the R seed, or Python's `random` and numpy seeds. Seed any other framework yourself from `seed`.

## The output contract

The wrappers write these files. They validate first, so a mistake stops the task and names the function, what it returned and what was expected. The `main.nf` declares these exact names, so Nextflow also fails if a file is missing.

| File | Content | Read by | Enforced |
| --- | --- | --- | --- |
| `<dataset>-<fold>-result.csv` | the columns `sample_name`, `y`, `phat`, `method_name`, `dataset`, `fold`, in this order | `combine_tables.R`, `calculate_classification_metrics.py` | one row per test sample, sample names match in order, `y` is 0 or 1, `phat` is numeric with no NaN or infinity and within [0, 1]. Written rounded to 3 decimals, as in the existing methods. |
| `<method>-<dataset>_features_selected.csv` | the columns `feature`, `view`, `coef`, `method`, `dataset_name`, in this order | `merge_selected_features.R` | required columns are present, at least one row, every `view` is a real view, every `feature` is a real feature of that view, `coef` is finite, no duplicated feature and view pair |
| `<method>-<dataset>_selected_hyperparameters.json` | the fields `dataset`, `method`, `analysis_stage`, `parameters`, where each parameter has `value` and `treatment` | `merge_selected_hyperparameters.py` | fields are present, `treatment` is one of `tuned`, `fixed`, `default`, `data-derived` |

Why [0, 1]: the metrics threshold `phat` at `params.threshold` and compute a log loss, so a raw score would give wrong numbers without any error.

Feature names are passed through exactly as the data has them, and the two data formats can differ. In rosmap the MAE names look like `epigenomics_cg00095526`, and the MuData names look like `cg00095526`.

## How to test

| Level | Command | Needs | Proves |
| --- | --- | --- | --- |
| Self-check | `add_method.py check <method>` | R or Python, plus numpy and pandas for Python | your functions meet the contract on synthetic data, and the model survives saving. Prints PASS or FAIL per function. |
| Container | `add_method.py check-image <method>` | Docker | the image qualifies, see below |
| Stub | `add_method.py test <method> --stub` | Docker | the Nextflow wiring of the four processes, and that their stub blocks create every declared output |
| Small dataset | `add_method.py test <method>` | Docker | the whole path on real data: rosmap, 2 folds, feature selection and metrics, for this method only |

`test` works in one of two ways, and prints the exact `nextflow run` command either way. Add `--dry-run` to print it and start nothing.

- **`nextflow` is on your PATH (Linux, Mac).** It runs in place, in this repository, with `-profile docker,test`, or with `-profile apptainer,test` if you add `--profile apptainer`. No Slurm is needed. Work folders go to `work/`, and output to `results/add_method_test/<method>/`.
- **No `nextflow`, as on Windows.** It runs Nextflow in the `nextflow/nextflow:24.10.2` container and copies the pipeline to `/tmp/messi_add_method/<method>` on the Docker side. Nextflow in a container starts task containers through the host's Docker daemon, and a path must mean the same to both.

Both copy the four key output files to `results/add_method_test/<method>/`, then print the metrics and PASS or FAIL. To run several methods together, use `add_method.py test <method> --also <other_method>`.

`-stub` on `main.nf` does not work: existing processes such as `UNCOMPRESS_RECORD` have no stub block, and Nextflow 24.10.2 stops on those with `Cannot invoke method clone() on null object`. That is why `--stub` runs only the method's own processes.

To build your own command, `add_method.py test <method> --print-skip-flags` prints the flags that turn off every other method.

The test writes its own samplesheet, with a path to `work/_inputs/rosmap.tar.gz`, because `data/samplesheet_test_small.csv` points at a Sockeye path. The tar file sits under `work/` because `tar_path` is a plain string that Nextflow does not stage, and `work/` is what it mounts into each Docker task container.

### On Sockeye

```bash
module load CVMFS_CC apptainer/1.3.5 java/21.0.1 nextflow/24.10.2
set -a; source .env; set +a
nextflow run main.nf -profile sockeye,test --samplesheet data/samplesheet_test_small.csv \
  --selectFeature true --outdir results/test_<method> -ansi-log false \
  $(python3 bin/adding_method/add_method.py test <method> --print-skip-flags)
```

## Containers

The module carries `label '<method>'`, and `nextflow.config` holds one line, `withLabel: <method> { container = '<image>' }`. The same line serves `-profile docker` and `-profile apptainer`: Apptainer converts the image and caches it.

The command asks you to choose one of two options.

**Reuse an existing image.** This works if it already has every package your functions use. The examples use `tonyliang19/rgcca:latest` for R and `tonyliang19/eipy:latest` for Python, which has scikit-learn. `--container` takes a label from `nextflow.config`, a short image name, or a full image name.

**Generate a Dockerfile**, with `--container new`, `FROM tonyliang19/r_method_base_dev` or `tonyliang19/python_method_base_dev`. The image is called `tonyliang19/<method>:latest`, and `--container new:USER/NAME:TAG` overrides that. Add your packages, then:

```bash
docker build -t tonyliang19/<method>:latest -f containers/dockerfiles/<method>.Dockerfile containers/dockerfiles
python bin/adding_method/add_method.py check-image <method>
docker push tonyliang19/<method>:latest

# Sockeye only: compute nodes have no internet, so pull once on the login node.
apptainer pull --dir "$APPTAINER_IMAGE_CACHE_DIR" tonyliang19-<method>-latest.img docker://tonyliang19/<method>:latest
```

The file name above is the one Nextflow looks for in its Apptainer cache. Build for `linux/amd64`.

### Is my container good enough?

Very little is needed: reuse an image, or start from the base image and add your method's package. You keep no list of your own dependencies, because `check-image` runs your real functions inside the image.

Required, as listed in `bin/adding_method/required_packages.json`:

| | Required | Why |
| --- | --- | --- |
| Commands | `bash`, `ps` | Nextflow's task wrapper uses them |
| R | `Rscript`, `MultiAssayExperiment`, `HDF5Array` | what the wrappers load; everything else they use is base R |
| Python | `python`, `numpy`, `pandas`, `mudata` | what the wrappers load; everything else they use is the standard library |

Both base images have all of this.

```bash
python bin/adding_method/add_method.py check-image <method>
python bin/adding_method/add_method.py check-image <method> --image someuser/someimage:1.0
```

It runs the image as the pipeline does, with a non-root user and `--entrypoint ''`, and prints PASS, FAIL or WARN per item:

1. The image starts, and `bash` and `ps` exist.
2. The language runtime and the required packages load.
3. Your three functions run inside the image, through the same validators as `check`. A missing package fails with its name and the Dockerfile line to add.
4. Warns if packages live under a home directory. Docker mounts into `/home/rstudio/...` and Apptainer binds `$HOME`, so such packages can vanish.
5. Warns if the image is not amd64.

Two pieces of advice:

- Pin your method's package version in the Dockerfile, and do not rely on `:latest` for a published result. Give the image a version tag or a digest, and record it.
- `check-image` passing on Docker does not prove Apptainer behaviour. Apptainer runs with your own user and `$HOME`, and binds different paths. Before relying on it, run one small dataset under Apptainer.

## Common errors

| What you see | What it means | Fix |
| --- | --- | --- |
| `CONTRACT ERROR in predict_proba()` and so on | a function returned the wrong thing. The message says what it got and what is expected. | fix it in the core file, then run `check` |
| `fit() is not implemented yet` | the stub is still there | fill it in, or run with `--skip_<method> true` |
| `there is no package called 'x'`, `No module named 'x'` | the image lacks a package | use the line `check-image` prints |
| `messi_run.R: Permission denied`, exit code 126 | the script lost its executable bit, usually from a commit on Windows | `git add --chmod=+x modules/<method>/resources/usr/bin/messi_run.*` |
| `Cannot find the marker comment` | a `// add_method:...` comment was removed | restore it from git |
| `Cannot use method name ... 'sim'` | `merge_selected_features.R` treats file names containing `sim` as simulated data | choose another name |
| `The image ... is not built yet` | you chose a new container | run the `docker build` line it prints |
| `Cannot invoke method clone() on null object` | `-stub` on `main.nf`, see above | use `add_method.py test <method> --stub` |
| `Process requirement exceeds available memory` on a small machine | a process label asks for more than the machine has | use `-profile docker,test`, which caps it, or set `--max_memory` and `--max_cpus` |
| the same failure repeats several times on Sockeye | `conf/sockeye.config` retries `_TRAIN` and `_SELECT_FEATURE` whatever the error | run `check` first, so contract errors never reach the cluster |
