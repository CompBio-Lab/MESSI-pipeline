# This is the base image for methods implemented in Python
# It contains a jupyter lab for development and debug purposes
# Use the python_method_base without _dev suffix for final base image

# TODO: Could possibly change to other base image?
FROM jupyter/scipy-notebook:x86_64-ubuntu-22.04

# Installing core dependencies for methods
RUN pip install \
	docopt \
	muon \
	matplotlib \
	h5py \
	mudata
