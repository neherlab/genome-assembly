# create and activate conda environment
conda env create -f conda_env.yml
conda activate genass

# install minipolish
pip3 install git+https://github.com/rrwick/Minipolish.git

# Download miniasm_and_minipolish.sh script
wget -N -O scripts/miniasm_and_minipolish.sh \
    https://raw.githubusercontent.com/rrwick/Minipolish/main/miniasm_and_minipolish.sh