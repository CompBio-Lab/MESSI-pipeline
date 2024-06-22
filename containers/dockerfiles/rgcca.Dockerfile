# Method for RGCCA
# RGCCA: Regularized and Sparse Generalized Canonical Correlation Analysis for Multiblock Data

# This base image has MAE and MuData installed, plus docopt
# So only dep is only the method itself
FROM tonyliang19/r_method_base_dev
# This installs the method
#RUN Rscript -e "install.packages('RGCCA')"
# NOTE: This is temporary fix, so RGCCA still need a dev branch
# see issue https://github.com/rgcca-factory/RGCCA/issues/79
RUN Rscript -e "devtools::install_github('rgcca-factory/rgcca@add_probs_in_predict')"
