FROM dabinjeong/biomarker:0.1.1

# Install revelevant deps
RUN pip install \
	anndata \
	docopt \
	mudata \
	jupyter \
	jupyterlab \
	matplotlib
# Run jupyter lab
EXPOSE 8888
# Create workdir
WORKDIR /app
ENTRYPOINT ["jupyter", "lab","--ip=0.0.0.0","--allow-root"]
