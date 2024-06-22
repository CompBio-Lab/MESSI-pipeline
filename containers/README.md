# Containers

This is the directory to store list of singularity `*.sif` definition files, or list of Dockerfiles `*_Dockerfile` that defines the images used in the project.

All names of used containers are listed in `./names.md`

You could do the following:

```bash
bash ~/bin/pull_all.sh
```

To download all containers from dockerhub as singularity images and store them in the `$IMAGE_DIR` (by default it's `$PROJECT_PATH/images`) , you could override it and change to your preference by modiying the script `bin/helper.sh`.
