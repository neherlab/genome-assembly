# create and activate conda environment
# conda env create -f conda_env.yml

# Download miniasm_and_minipolish.sh script
wget -N -O scripts/miniasm_and_minipolish.sh \
    https://raw.githubusercontent.com/rrwick/Minipolish/main/miniasm_and_minipolish.sh

# TODO: nextflow self-update
# TODO: set the location of the environment in the nextflow.config file