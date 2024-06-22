# This contains both mixOmics and multiview
FROM tonyliang19/mixdiablo

RUN apt-get update && apt-get install -y libxt6

# This is the new ver command
RUN Rscript -e "install.packages('glmnet')" \
	-e "install.packages('randomForest')" \
	-e "install.packages('caret')" \
	-e "install.packages('latex2xp')" \
	-e "install.packages('multiview')" 

RUN Rscript -e "BiocManager::install(c('mixOmics', 'MultiAssayExperiment', 'HDF5Array'))"