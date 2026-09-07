# MESSI Method Template Generator

This directory contains tools for automatically generating method templates for the MESSI pipeline.

## Overview

The template generator creates all necessary Nextflow workflows, process definitions, and binary script templates for adding a new multiomics integration method to the MESSI pipeline.

## Quick Start

### Using the Template Generator

From the project root directory:

```bash
python bin/adding_method/adding_method.py \
  --method=my_method \
  --language=R \
  --outdir=. \
  --docker_user=your_dockerhub_username
```

**Parameters:**
- `--method`: Name of your method (lowercase, underscore-separated)
- `--language`: Either `R` or `Python`
- `--outdir`: Output directory (use `.` for project root)
- `--docker_user`: Your DockerHub username
- `--force_update`: Optional flag to overwrite existing files

### Using the Shell Wrapper (Example)

You can also use the shell script `adding_method.sh` as a reference:

```bash
# Edit the script to set your method parameters
vim bin/adding_method/adding_method.sh

# Run it
bash bin/adding_method/adding_method.sh
```

## What Gets Generated

Running the template generator creates:

### 1. Nextflow Workflows

```
subworkflows/methods/<method>/main.nf
```
Main workflow that orchestrates the method's processes.

### 2. Nextflow Process Definitions

```
modules/<method>/preprocess/main.nf
modules/<method>/train/main.nf
modules/<method>/predict/main.nf
modules/<method>/select_feature/main.nf
```
Process definitions for each step of the method.

### 3. Binary Script Templates

#### For R methods:
```
modules/<method>/preprocess/resources/usr/bin/<method>_preprocess.R
modules/<method>/train/resources/usr/bin/<method>_train.R
modules/<method>/predict/resources/usr/bin/<method>_predict.R
modules/<method>/select_feature/resources/usr/bin/<method>_select_feature.R
```

#### For Python methods:
```
modules/<method>/preprocess/resources/usr/bin/<method>_preprocess.py
modules/<method>/train/resources/usr/bin/<method>_train.py
modules/<method>/predict/resources/usr/bin/<method>_predict.py
modules/<method>/select_feature/resources/usr/bin/<method>_select_feature.py
```

### 4. Automatic Registration

The generator automatically registers your method in:
- `subworkflows/cross_validation/r/main.nf` (for R methods)
- `subworkflows/cross_validation/python/main.nf` (for Python methods)

Adds:
- Include statement
- Skip parameter
- Method instantiation block
- Output mixing

## Directory Structure

```
bin/adding_method/
├── README.md                    # This file
├── adding_method.sh             # Example shell wrapper
├── adding_method.py             # Main CLI script
└── messi_add_method/            # Python package
    ├── __init__.py
    ├── create_method.py         # Core template generation logic
    └── method-template/         # Jinja2 templates
        ├── modules/
        │   └── method/
        │       ├── preprocess/
        │       │   ├── main.nf
        │       │   └── resources/usr/bin/
        │       │       ├── method_preprocess.R
        │       │       └── method_preprocess.py
        │       ├── train/
        │       │   ├── main.nf
        │       │   └── resources/usr/bin/
        │       │       ├── method_train.R
        │       │       └── method_train.py
        │       ├── predict/
        │       │   ├── main.nf
        │       │   └── resources/usr/bin/
        │       │       ├── method_predict.R
        │       │       └── method_predict.py
        │       └── select_feature/
        │           ├── main.nf
        │           └── resources/usr/bin/
        │               ├── method_select_feature.R
        │               └── method_select_feature.py
        └── subworkflows/
            └── methods/
                └── method/
                    └── main.nf
```

## Template Files Explained

### Nextflow Templates (`.nf` files)

All `.nf` files use **Jinja2 templating** with the following variables:

- `{{ method }}` - Method name (lowercase)
- `{{ method|upper }}` - Method name (uppercase)
- `{{ method|lower }}` - Method name (lowercase, explicit)
- `{{ docker_user }}` - DockerHub username
- `{{ ext }}` - File extension (`R` or `py`)
- `{{ language }}` - Programming language

Example:
```groovy
process {{ method|upper }}_PREPROCESS {
  container "${ onSockeye ?
    '{{ method|lower }}.sif' :
    '{{ docker_user|lower }}/{{ method|lower }}:latest' }"
  // ...
}
```

Becomes (for method="my_method", docker_user="myuser"):
```groovy
process MY_METHOD_PREPROCESS {
  container "${ onSockeye ?
    'my_method.sif' :
    'myuser/my_method:latest' }"
  // ...
}
```

### Binary Script Templates

Templates include:
- **Shebang line** (`#!/usr/bin/env Rscript` or `#!/usr/bin/env python`)
- **Docopt documentation** for CLI argument parsing
- **Helper functions** commonly needed
- **Main function** with TODO comments
- **Placeholder logic** to replace with your method

## After Generation

Once templates are generated, you need to:

1. **Create Dockerfile** (not auto-generated)
   - Location: `containers/dockerfiles/<method>.Dockerfile`
   - See: `docs/tutorials/adding_method_guide.md`

2. **Implement binary scripts**
   - Replace TODO sections in generated scripts
   - Add your method's actual logic
   - Test scripts independently

3. **Build and push container**
   ```bash
   docker build -f containers/dockerfiles/<method>.Dockerfile \
     -t <user>/<method>:latest .
   docker push <user>/<method>:latest
   ```

4. **Test the workflow**
   ```bash
   nextflow run main.nf --skip_all_except_<method>
   ```

## Template Modification

To modify the templates:

1. Edit files in `messi_add_method/method-template/`
2. Use Jinja2 syntax for dynamic content
3. Test by generating a new method

## Examples

### Generate R Method

```bash
python bin/adding_method/adding_method.py \
  --method=my_r_method \
  --language=R \
  --outdir=. \
  --docker_user=myusername
```

### Generate Python Method

```bash
python bin/adding_method/adding_method.py \
  --method=my_py_method \
  --language=Python \
  --outdir=. \
  --docker_user=myusername
```

### Force Update Existing Method

```bash
python bin/adding_method/adding_method.py \
  --method=existing_method \
  --language=R \
  --outdir=. \
  --docker_user=myusername \
  --force_update
```

**Warning**: Force update will overwrite your custom implementations!

## Requirements

- Python 3.6+
- Python packages:
  - `docopt`
  - `jinja2`
  - `pyyaml`

Install with:
```bash
pip install docopt jinja2 pyyaml
```

## Troubleshooting

### "Template not found"

**Cause**: Script run from wrong directory

**Solution**: Always run from project root:
```bash
cd /path/to/MESSI-pipeline
python bin/adding_method/adding_method.py ...
```

### "Method already exists"

**Cause**: Method subworkflow already present

**Solution**: 
- Choose different method name, or
- Use `--force_update` to overwrite (careful!)

### "Permission denied"

**Cause**: Generated scripts not executable

**Solution**:
```bash
chmod +x modules/<method>/*/resources/usr/bin/*
```

## Complete Documentation

For comprehensive documentation on adding methods, see:
- **[Complete Method Guide](../../docs/tutorials/adding_method_guide.md)**
- **[R Method Tutorial](../../docs/tutorials/adding_r-based_method/adding_r-based_method.md)**

## Support

For issues or questions:
1. Check the [main documentation](../../docs/tutorials/adding_method_guide.md)
2. Look at existing method implementations (e.g., `demo_logit`, `sklearn`)
3. Review `.nextflow.log` for debugging information
