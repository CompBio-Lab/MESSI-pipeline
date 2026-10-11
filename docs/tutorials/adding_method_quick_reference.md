# Quick Reference: Adding a Method to MESSI Pipeline

This is a condensed quick-reference guide. For complete details, see [adding_method_guide.md](adding_method_guide.md).

## Prerequisites

- [ ] Method implemented in R or Python
- [ ] List of dependencies
- [ ] Docker installed
- [ ] DockerHub account

## Step 1: Generate Template (5 minutes)

```bash
cd /path/to/MESSI-pipeline

python bin/adding_method/adding_method.py \
  --method=my_method \
  --language=R \
  --outdir=. \
  --docker_user=myusername
```

Replace:
- `my_method` with your method name (lowercase, use underscore)
- `R` with `Python` if using Python
- `myusername` with your DockerHub username

## Step 2: Create Dockerfile (10 minutes)

Create `containers/dockerfiles/my_method.Dockerfile`:

**For R:**
```dockerfile
FROM tonyliang19/r_method_base_dev
RUN Rscript -e "install.packages(c('pkg1', 'pkg2'))"
```

**For Python:**
```dockerfile
FROM python:3.9-slim
RUN pip install mudata numpy pandas scikit-learn docopt
```

Build and push:
```bash
docker build -f containers/dockerfiles/my_method.Dockerfile -t myusername/my_method:latest .
docker push myusername/my_method:latest
```

## Step 3: Implement Scripts (Main Work)

### 3.1 Preprocessing (`modules/my_method/preprocess/resources/usr/bin/my_method_preprocess.{R,py}`)

**Must do:**
- Split data into train/test folds
- Output structure: `fold_N/fold_N_{tr,te}/`
- Make executable: `chmod +x`

### 3.2 Training (`modules/my_method/train/resources/usr/bin/my_method_train.{R,py}`)

**Must do:**
- Train model on training data
- Output: `<dataset>-<fold>-my_method_model.{rds,pkl}` and test data file
- Make executable: `chmod +x`

### 3.3 Prediction (`modules/my_method/predict/resources/usr/bin/my_method_predict.{R,py}`)

**Must do:**
- Generate predictions on test data
- Output CSV with **exactly these columns**:
  - `sample_name` - Sample identifier
  - `y` - True label (0 or 1)
  - `phat` - Predicted probability of y=1
  - `method_name` - Your method name
  - `dataset` - Dataset name
- Make executable: `chmod +x`

### 3.4 Feature Selection (OPTIONAL)

Only if your method provides feature importance/selection.

## Step 4: Test (10 minutes)

```bash
# Quick test with stub
nextflow run main.nf -stub-run

# Real test on small data
nextflow run main.nf \
  --input test_data/samplesheet.csv \
  --outdir results_test \
  --skip_my_method=false
```

## Common Mistakes Checklist

- [ ] Scripts missing shebang (`#!/usr/bin/env Rscript` or `#!/usr/bin/env python`)
- [ ] Scripts not executable (`chmod +x`)
- [ ] Container name mismatch in `.nf` files
- [ ] Wrong output file names/structure
- [ ] Missing required columns in prediction CSV
- [ ] Wrong data format (MAE vs MuData)

## File Locations Summary

```
MESSI-pipeline/
├── bin/adding_method/                    # Template generator
├── containers/dockerfiles/
│   └── my_method.Dockerfile              # YOUR DOCKER
├── subworkflows/
│   ├── cross_validation/
│   │   ├── r/main.nf                     # Auto-updated for R
│   │   └── python/main.nf                # Auto-updated for Python
│   └── methods/my_method/
│       └── main.nf                       # Auto-generated
└── modules/my_method/
    ├── preprocess/
    │   ├── main.nf                       # Auto-generated
    │   └── resources/usr/bin/
    │       └── my_method_preprocess.R    # YOU IMPLEMENT
    ├── train/
    │   ├── main.nf                       # Auto-generated
    │   └── resources/usr/bin/
    │       └── my_method_train.R         # YOU IMPLEMENT
    ├── predict/
    │   ├── main.nf                       # Auto-generated
    │   └── resources/usr/bin/
    │       └── my_method_predict.R       # YOU IMPLEMENT
    └── select_feature/
        ├── main.nf                       # Auto-generated
        └── resources/usr/bin/
            └── my_method_select_feature.R # YOU IMPLEMENT (optional)
```

## Expected Output Structure

```
results/
├── my_method_preprocess/<dataset>/
│   ├── fold_1/
│   │   ├── fold_1_tr/    # Training data
│   │   └── fold_1_te/    # Test data
│   └── fold_2/
│       ├── fold_2_tr/
│       └── fold_2_te/
├── my_method_train/<dataset>/
│   ├── fold_1/
│   │   ├── <dataset>-fold_1-my_method_model.rds
│   │   └── <dataset>-fold_1-test_data.rds
│   └── fold_2/
│       ├── <dataset>-fold_2-my_method_model.rds
│       └── <dataset>-fold_2-test_data.rds
└── my_method_predict/<dataset>/
    ├── fold_1/
    │   └── <dataset>-fold_1-result_table.csv  # Has 5 required columns
    └── fold_2/
        └── <dataset>-fold_2-result_table.csv
```

## Debugging Tips

1. **Check logs**: `work/<hash>/.command.log`
2. **Test scripts independently**: Run outside Nextflow first
3. **Use stub mode**: `-stub-run` for quick validation
4. **Enable debug**: Add `params.debug = true`
5. **Check existing examples**: Look at `demo_logit` or `sklearn`

## Language Differences

| Aspect | R | Python |
|--------|---|--------|
| Data format | MultiAssayExperiment (MAE) | MuData |
| Data shape | p × N (features × samples) | N × p (samples × features) |
| File extension | `.rds` | `.pkl`, `.h5mu` |
| Workflow | `CV_R` | `CV_PYTHON` |
| Input channel | `mae_copy` | `mu_copy` |
| Shebang | `#!/usr/bin/env Rscript` | `#!/usr/bin/env python` |

## Next Steps

After your method works:
1. Document any special configuration in your method's README
2. Add to pipeline documentation
3. Create pull request
4. Celebrate! 🎉

## Full Documentation

- **[Complete Guide](adding_method_guide.md)** - Comprehensive documentation
- **[R Method Tutorial](adding_r-based_method/adding_r-based_method.md)** - Detailed R example
- **[Template Generator README](../../bin/adding_method/README.md)** - Template tool docs
