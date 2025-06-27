# Environment for Mogonet
# Need to bind path to get data and script of mogonet
#FROM tverous/pytorch-notebook:latest
FROM quay.io/jupyter/pytorch-notebook:cuda12-notebook-7.1.0

# Install python base packages
RUN pip install \
        anndata==0.10.3 \
        docopt==0.6.2 \
        numpy==1.26.0 \
        mudata==0.2.3 \
        scikit-learn==1.3.1 \
        pandas==2.1.1 \
        pytest==7.4.2

# Install mogonet in separate layer as this could be changing over time
RUN pip install Mogonet==2.0.1
