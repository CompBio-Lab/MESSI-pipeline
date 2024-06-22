FROM tonyliang19/muon-py
# install mowgli according to github repo
# https://github.com/cantinilab/mowgli/
RUN pip install mowgli \
		docopt
