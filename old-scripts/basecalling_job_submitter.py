import os
import glob
import shutil
import time
import argparse

base_dir = os.getcwd()+'/'
fast5_path = base_dir+'fast5/'
basecalling_path = base_dir+'basecalling/'
submit_script = '~/nanopore_scripts/guppy_scripts/guppy_basecalling.sh'

# Make directory where the basecalling takes place
if not os.path.exists(basecalling_path):
    os.mkdir(basecalling_path)

def call_guppy(flow_cell,kit):
    fast5_files = glob.glob(fast5_path+'*.fast5')
    for fast5_file in fast5_files:
        # Make directory for the fastq
        fast5_file_directory_name = fast5_file.split('/')[-1].split('.')[0]
        fast5_file_directory = basecalling_path+fast5_file_directory_name
        os.mkdir(basecalling_path+fast5_file_directory_name)

        # Move read to created directory
        shutil.move(fast5_file,fast5_file_directory+'/nanopore_raw_read.fast5')

        # Call guppy
        call = ['sbatch',submit_script,fast5_file_directory,fast5_file_directory+'/fastq',flow_cell,kit,fast5_file_directory+'/barcoded_output']
        os.system(' '.join(call))
        print(call)
    raw_file_counts = len(fast5_files)  
    return len(fast5_files)


if __name__=="__main__":
    # Parse arguments needed for guppy
    parser = argparse.ArgumentParser(description = "stage reads and call bases")
    parser.add_argument("--flowcell", type=str, help="flowcell")
    parser.add_argument("--kit", type=str, help="library kit")
    parser.add_argument("--interval", type=int, default=600, help="number of second delay in the cycle")
    params = parser.parse_args()

    # Scan for files every defined interval
    while True:
        submitted_files = call_guppy(params.flowcell,params.kit)
        print('Submitted %d fast5 file to guppy' % (submitted_files))
        time.sleep(params.interval)
