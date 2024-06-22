# This file creates a R image
# for cooperative learning

FROM rocker/tidyverse

# Install required packages

# This is not working
#RUN Rscript -e "install.packages(c('glmnet', \
#				'randomForest'))"

# This works, consider update it as above
# Or perhaps just use install.r check this out
RUN apt-get update && apt-get install -y libxt6

# This is the new ver command
RUN Rscript -e "install.packages('glmnet')" \
	-e "install.packages('randomForest')" \
	-e "install.packages('caret')" \
	-e "install.packages('latex2xp')" \
	-e "install.packages('multiview')" \
	-e "install.packages('here')"

RUN Rscript -e "devtools::install_github('tonyliang19/rhelpers')"
#RUN Rscript -e "install.packages(c('devtools')"
