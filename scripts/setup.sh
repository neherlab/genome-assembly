# create and activate conda environment
conda env create -f conda_env.yml

# install minipolish
pip3 install git+https://github.com/rrwick/Minipolish.git

# Download miniasm_and_minipolish.sh script
wget -N -O scripts/miniasm_and_minipolish.sh \
    https://raw.githubusercontent.com/rrwick/Minipolish/main/miniasm_and_minipolish.sh

# TODO: activate the environment
# TODO: update nextflow
# TODO: set the location of the environment in the nextflow.config file