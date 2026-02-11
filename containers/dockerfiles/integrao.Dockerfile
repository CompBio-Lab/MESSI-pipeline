FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime@sha256:393fa73fbcfd290b46483cebc29a284fcc10d5be493e3d4844f9781152c2daa4
# Install Python dependencies
RUN pip install \
	anndata==0.10.3 \
        docopt==0.6.2 \
        numpy==1.26.0 \
        mudata==0.2.3 \
        scikit-learn==1.3.1 \
        pandas==2.1.1 \
	jupyterlab==4.5.3 \
	captum==0.8.0

# And install integrao in separate layer
RUN pip install integrao==0.1.3

# Start JupyterLab when the container runs
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root"]

