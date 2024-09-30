import argparse
import os
import shutil
import gzip
import glob
import logging
import datetime
import subprocess
from concurrent.futures import ThreadPoolExecutor
import time


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

    # Parallelize this loop to speed up the process

    def process_file(file_path, raw_data_dir, force):
        file_name = os.path.basename(file_path)
        if '_R1_' in file_name:
            new_name = 'forward.fastq.gz'
        elif '_R2_' in file_name:
            new_name = 'reverse.fastq.gz'
        elif '_I1_' in file_name:
            new_name = 'barcodes.fastq.gz'
        else:
            return

        new_file_path = os.path.join(raw_data_dir, new_name)

        # Copy and compress if necessary
        if os.path.exists(new_file_path) and not force:
            logger.info('File {} already exists in raw data directory. Skipping'.format(new_file_path))
            return

        if file_path.endswith('.gz'):
            shutil.copy(file_path, new_file_path)
        else:
            with open(file_path, 'rb') as f_in, gzip.open(new_file_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)

    # Use ThreadPoolExecutor to parallelize the process, use max 3 threads
    futures = []
    with ThreadPoolExecutor(max_workers=3) as executor:
        for file_path in files_to_process:
            logger.info('Processing file {}'.format(file_path))
            # future = executor.submit(process_file, file_path, raw_data_dir, force)
            # future.set_result(file_path)
            # futures.append(future)
            futures.append(executor.submit(process_file, file_path, raw_data_dir, force))
    
        logger.info(f'Waiting for {len(futures)} files to be processed')
        while len(futures) > 0:
            
            for future in futures:
                # if done print the result
                if future.done():
                    print()
                    # logger.info('File processed {}'.format(future.result()))
                    logger.info('File processed')
                    # logger.info(future.result())
                    futures.remove(future)
                    logger.info(f'Waiting for {len(futures)} files to be processed')
                else:
                    # Add a dot to the console to show progress, append to the same line
                    print('.', end='', flush=True)

            # Sleep for 30 seconds before checking again
            time.sleep(10)
           

    


    logger.info('Data staging complete')



        # with ThreadPoolExecutor() as executor:
        # executor.map(lambda file_path: process_file(file_path, raw_data_dir, force), files_to_process)



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

def link_output(output_name, input_dir):
    # Create symlink from output_name to input_dir/filename
    filename = os.path.basename(output_name)
    output_path = os.path.join(input_dir, filename)
    if os.path.exists(output_path):
        os.remove(output_path)
    os.symlink(filename, output_path)

def run_workflow(base_dir, p_trunc_len_f=0, p_trunc_len_r=0):
    # Create output directory and raw data directory
  
    # check if the input directory exists
    if not os.path.exists(base_dir):
        raise ValueError('Input directory does not exist')
    
    results = {}
    
    input_dir = os.path.join(base_dir, 'input')
    output_dir = os.path.join(base_dir, 'output')


    import_input_dir = os.path.join(input_dir ,'raw_data')
    import_output_name = 'paired-end-demux.qza'
    
    # Run qiime import
    #     qiime tools import \
    #       --type EMPPairedEndSequences \
    #       --input-path $RAW_DATA_DIR \
    #       --output-path $OUTPUT_DIR/paired-end-sequences.qza

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(import_output_name):
        logger.info('Import output already exists. Skipping')
    else:
        results['import']=subprocess.run(['qiime', 'tools', 'import', 
                           '--type', 'EMPPairedEndSequences', 
                           '--input-path', import_input_dir, 
                           '--output-path', import_output_name ])

    # link the output to the input directory
    link_output(import_output_name, input_dir)



    # Run qiime demux
    # qiime demux emp-paired \
    # --m-barcodes-file $BARCODES_FILE \
    # --m-barcodes-column barcode-sequence \
    # --p-rev-comp-mapping-barcodes \
    # --p-rev-comp-barcodes \
    # --i-seqs $INPUT_DIR/paired-end-sequences.qza \
    # --o-per-sample-sequences $OUTPUT_DIR/demux-full.qza \
    # --o-error-correction-details $OUTPUT_DIR/demux-details.qza

    demux_output_name = 'demux-full.qza'
    demux_details_output_name = 'demux-details.qza'
    demux_output = os.path.join(output_dir, demux_output_name)
    demux_details_output = os.path.join(output_dir, demux_details_output_name)

    # check if outputs already exist, skip if they do unless force is set to True
    if os.path.exists(demux_output) and os.path.exists(demux_details_output):
        logger.info('Demux outputs already exist. Skipping')
    else:
        results['demux'] = subprocess.run(['qiime', 'demux', 'emp-paired',
                                            '--m-barcodes-file', os.path.join(input_dir, 'mapping.txt'),
                                            '--m-barcodes-column', 'barcode-sequence',
                                            '--p-rev-comp-mapping-barcodes',
                                            '--p-rev-comp-barcodes',
                                            '--i-seqs', import_output_name,
                                            '--o-per-sample-sequences', demux_output,
                                            '--o-error-correction-details', demux_details_output])
    
    link_output(demux_output_name, input_dir)
    link_output(demux_details_output_name, input_dir)

    # Run qiime demux summarize
    # qiime demux summarize \
    # --i-data $INPUT_DIR/demux-full.qza \
    # --o-visualization $OUTPUT_DIR/demux-full.qzv

    demux_viz_output_name = 'demux-full.qzv'
    demux_viz_output = os.path.join(output_dir, demux_viz_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(demux_viz_output):
        logger.info('Demux visualization output already exists. Skipping')
    else:
        results['demux_viz'] = subprocess.run(['qiime', 'demux', 'summarize',
                                               '--i-data', demux_output,
                                               '--o-visualization', demux_viz_output])
    
    link_output(demux_viz_output_name, input_dir)



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
    demux_parser.add_argument('--p-trunc-len-f', type=int, default=0, help="\
                              Position at which forward read sequences should be \
                          truncated due to decrease in quality. This truncates \
                          the 3' end of the of the input sequences, which will \
                          be the bases that were sequenced in the last cycles. \
                          Reads that are shorter than this value will be \
                          discarded. After this parameter is applied there \
                          must still be at least a 12 nucleotide overlap \
                          between the forward and reverse reads. If 0 is \
                          provided, no truncation or length filtering will be \
                          performed")
    demux_parser.add_argument('--p-trunc-len-r', type=int, default=0, help="\
                              Position at which reverse read sequences should be truncated due to decrease in quality. \
                              This truncates the 3' end of the of the input sequences, which will be the bases that were \
                              sequenced in the last cycles. Reads that are shorter than this value will be discarded. \
                              After this parameter is applied there must still be at least a 12 nucleotide overlap between \
                              the forward and reverse reads. If 0 is provided, no truncation or length filtering will be \
                              performed")

    # Workflow subparser of run
    workflow_parser.add_argument('input_dir', type=str, help='Input directory')
    workflow_parser.add_argument('--p-trunc-len-f', type=int, default=0, help="\
                              Position at which forward read sequences should be \
                          truncated due to decrease in quality. This truncates \
                          the 3' end of the of the input sequences, which will \
                          be the bases that were sequenced in the last cycles. \
                          Reads that are shorter than this value will be \
                          discarded. After this parameter is applied there \
                          must still be at least a 12 nucleotide overlap \
                          between the forward and reverse reads. If 0 is \
                          provided, no truncation or length filtering will be \
                          performed")
    workflow_parser.add_argument('--p-trunc-len-r', type=int, default=0, help="\
                              Position at which reverse read sequences should be truncated due to decrease in quality. \
                              This truncates the 3' end of the of the input sequences, which will be the bases that were \
                              sequenced in the last cycles. Reads that are shorter than this value will be discarded. \
                              After this parameter is applied there must still be at least a 12 nucleotide overlap between \
                              the forward and reverse reads. If 0 is provided, no truncation or length filtering will be \
                              performed")




    args = parser.parse_args()
    logger.setLevel(args.log_level)

    if args.command == 'setup':
        stage_data(args.input_dir, args.output_dir)
    elif args.command == 'run':
        if args.subcommand == 'demux':
            demux_data(args.input_dir, args.output_dir, args.p_trunc_len_f, args.p_trunc_len_r)
        elif args.subcommand == 'denoise':
            denoise_data(args.input_dir, args.output_dir)
        elif args.subcommand == 'workflow':
            run_workflow(args.input_dir, args.output_dir, args.p_trunc_len_f, args.p_trunc_len_r)
        else:
            raise ValueError('Invalid subcommand')

if __name__ == '__main__':
    main()