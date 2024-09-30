import argparse
import os
import shutil
import gzip
import glob
import logging
import datetime


logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


# Create input, output and war_data directories in the output directory
def setup_directories(output_dir):
    local_input_dir = os.path.join(output_dir, 'input')
    local_output_dir = os.path.join(output_dir, 'output')
    local_raw_data_dir = os.path.join(output_dir, 'input', 'raw_data')

    os.makedirs(local_input_dir, exist_ok=True)
    os.makedirs(local_output_dir, exist_ok=True)
    os.makedirs(local_raw_data_dir, exist_ok=True)

    return local_input_dir, local_output_dir, local_raw_data_dir

def stage_data(input_dir, output_dir , force = False):
    # # Create output directory and raw data directory
    # raw_data_dir = os.path.join(output_dir, 'raw_data')
    # os.makedirs(raw_data_dir, exist_ok=True)

    [ output_dir , not_used_for_staging , raw_data_dir ] = setup_directories(output_dir)

    # Search for files starting with 'Undetermined' and having .fastq or .fastq.gz suffix
    search_patterns = ['**/Undetermined*.fastq', '**/Undetermined*.fastq.gz' , 'Undetermined*.fq' , 'Undetermined*.fq.gz']
    files_to_process = []
    for pattern in search_patterns:
        logger.debug('Searching for files with pattern {}'.format(pattern))
        logger.debug('Pattern: {}'.format(os.path.join(input_dir, pattern)))
        # print(glob.glob(os.path.join(input_dir, pattern), recursive=True))
        files_to_process.extend(glob.glob(os.path.join(input_dir, pattern), recursive=True))
        logger.debug('Files found: {}'.format(files_to_process))

    if len(files_to_process) == 0:
        raise ValueError('No files found in input directory')

    for file_path in files_to_process:
        file_name = os.path.basename(file_path)
        if '_R1_' in file_name:
            new_name = 'forward.fastq.gz'
        elif '_R2_' in file_name:
            new_name = 'reverse.fastq.gz'
        elif '_I1_' in file_name:
            new_name = 'barcodes.fastq.gz'
        else:
            continue

        new_file_path = os.path.join(raw_data_dir, new_name)

        # Copy and compress if necessary
        if os.path.exists(new_file_path) and not force:
            logger.info('File {} already exists in raw data directory. Skipping'.format(new_file_path))

        if file_path.endswith('.gz'):
            shutil.copy(file_path, new_file_path)
        else:
            with open(file_path, 'rb') as f_in, gzip.open(new_file_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        
    # Find mapping file in input dir and copy it into outputif it exists and copy it to the output directory as mapping.txt
    # throw an error if it does not exist

    search_patterns = ['**/*mapping*']
    mapping_files_to_process = []
    for pattern in search_patterns:
        mapping_files_to_process.extend(glob.glob(os.path.join(input_dir, pattern)))


    mapping_file = None
    if len(mapping_files_to_process) == 0:
        # raise ValueError('No mapping file found in input directory')
        logger.warning('No mapping file found in input directory')
    elif len(mapping_files_to_process) > 1:\
        raise ValueError('Multiple mapping files found in input directory')
    else:
        mapping_file = mapping_files_to_process[0]

    if os.path.exists(os.path.join(output_dir, 'mapping.txt')) and not force:
        logger.info('Mapping file already exists in output directory. Skipping')
    elif mapping_file and os.path.exists(mapping_file):
        shutil.copy(mapping_file, os.path.join(output_dir, 'mapping.txt'))
    else:
        pass

    # Create provenance file in output directory and append information about the data staging

    with open(os.path.join(output_dir, 'provenance.txt'), 'a') as f:
        f.write('# Data staging information\n')
        f.write('Data staged from {}\n'.format(input_dir))
        f.write('Raw data stored in {}\n'.format(raw_data_dir))
        f.write('Mapping file stored in {}\n'.format(os.path.join(output_dir, 'mapping.txt')))
        f.write('Data staged at {}\n'.format(datetime.datetime.now()))


def main():
    parser = argparse.ArgumentParser(description='QIIME Pipeline Script')

    parser.add_argument('--log_level', default=logging.INFO , 
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], 
                        help='Set the logging level'
                        )
    parser.add_argument('--log_file', default=None, 
                        help='Set the log file'
                        )
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')


    subparsers = parser.add_subparsers(dest='command')

    # Staging data subparser
    stage_parser = subparsers.add_parser('setup', help='Stage data')
    stage_parser.add_argument('input_dir', type=str, help='Input directory')
    stage_parser.add_argument('output_dir', type=str, help='Output directory')

    # Run qiime subparser
    run_parser = subparsers.add_parser('run', help='Run QIIME')

    # Run subparser of run for individual commands
    run_subparsers = run_parser.add_subparsers(dest='subcommand')


    demux_parser = run_subparsers.add_parser('demux', help='Demultiplex data')
    denoise_parser = run_subparsers.add_parser('denoise', help='Denoise data')
    workflow_parser = run_subparsers.add_parser('workflow' , help='Run QIIME workflow')


    # Demux subparser of run
    demux_parser.add_argument('input_dir', type=str, help='Input directory')

    # Workflow subparser of run
    workflow_parser.add_argument('input_dir', type=str, help='Input directory')




    args = parser.parse_args()
    logger.setLevel(args.log_level)

    if args.command == 'setup':
        stage_data(args.input_dir, args.output_dir)

if __name__ == '__main__':
    main()