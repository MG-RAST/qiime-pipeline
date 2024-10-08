#!/usr/bin/env python

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
import json
import sys

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


class File:
    # File class to store file information based on https://www.commonwl.org/v1.2/CommandLineTool.html#File

    def __init__(self, name = None):

        self.name = name
        self.id = None
        self.location = None
        self.path = None
        self.basename = None
        self.dirname = None
        self.nameroot = None
        self.nameext = None
        self.checksum = None
        self.size = None
        self.secondaryFiles = None
        self.provenance = None

    def __str__(self):
        return self.name
    
    def __repr__(self):
        return self.name
    
    def __getitem__(self, key):
        return getattr(self, key)
    
    def __setitem__(self, key, value):
        setattr(self, key, value)

    def __iter__(self):
        return iter(self.__dict__.items())

    # Dump as json
    def to_json(self):
        return json.dumps(self.__dict__)
    
    def add_secondary_file(self, file):
        if self.secondaryFiles is None:
            self.secondaryFiles = []
        self.secondaryFiles.append(file)
    
    def add_file(self, filepath):
        self.name = os.path.basename(filepath)
        self.path = filepath
        self.basename = os.path.basename(filepath)
        self.dirname = os.path.dirname(filepath)
        self.nameroot, self.nameext = os.path.splitext(self.basename)
        self.size = os.path.getsize(filepath)
        self.checksum = self.md5sum(filepath)

    def md5sum(self, filepath):
        # Calculate md5sum of file  
        import hashlib
        md5 = hashlib.md5()
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                md5.update(chunk)  
    

class FileProvenance:

    def __init__(self, name = None):
        self.name = name
        self.id = None
        self.source = None
        self.destination = None

class Provenance:
    # Provenance class to store file provenance information

    def __init__(self, output_dir , name = 'default'):
        self.output_dir = output_dir
        self.name = 'None'
        self.provenance = {}

    def add(self, key, value):
        self.provenance[key] = value

    def update(self, key, value):
        self.provenance[key] = value
        self.write()
    
    def write(self):
        # dump as json
        with open(self.provenance_file(), 'w') as f:
            json.dump(self.provenance, f)

    def read(self):
        with open(self.provenance_file(), 'r') as f:
            self.provenance = json.load(f)
        return self.provenance
    
    def provenance_file(self):
        return os.path.join(self.output_dir, self.name , ".prov")


    def __getitem__(self, key):
        return self.provenance[key]
    
    def __str__(self):
        return str(self.provenance)
    
    def __repr__(self):
        return str(self.provenance)
    





# Create input, output and war_data directories in the output directory
def setup_directories(output_dir):
    local_input_dir = os.path.join(output_dir, 'input')
    local_output_dir = os.path.join(output_dir, 'output')
    local_raw_data_dir = os.path.join(output_dir, 'input', 'raw_data')

    os.makedirs(local_input_dir, exist_ok=True)
    os.makedirs(local_output_dir, exist_ok=True)
    os.makedirs(local_raw_data_dir, exist_ok=True)




    return local_input_dir, local_output_dir, local_raw_data_dir

def proveance_file(output_dir, name, message):
    with open(os.path.join(output_dir, name , ".prov"), 'a') as f:
        f.write(message)

def stage_data(input_dir, output_dir , force = False):
    # # Create output directory and raw data directory
    # raw_data_dir = os.path.join(output_dir, 'raw_data')
    # os.makedirs(raw_data_dir, exist_ok=True)

    [ output_dir , not_used_for_staging , raw_data_dir ] = setup_directories(output_dir)

    results = {}

    # Get classifier from https://data.qiime2.org/classifiers/sklearn-1.4.2/greengenes/gg-13-8-99-515-806-nb-classifier.qza and store it in the input directory
    classifier_url = 'https://data.qiime2.org/classifiers/sklearn-1.4.2/greengenes/gg-13-8-99-515-806-nb-classifier.qza'
    classifier_output = os.path.join(output_dir, 'gg-13-8-99-515-806-nb-classifier.qza')
    if os.path.exists(classifier_output):
        logger.info('Classifier already exists in input directory. Skipping')
    else:
        logger.info('Downloading classifier')
        logger.debug("Options: {} -O {}".format(classifier_url, classifier_output))
        results['classifier'] = subprocess.run(['wget', classifier_url, '-O', classifier_output])
        logger.debug('Classifier output: {}'.format(results['classifier']))

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

        proveance_file(output_dir, new_name, "ID: " + new_file_path)

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

def link_output(source, target_dir):
    # Create symlink from output_name to input_dir/filename
    
    if not os.path.exists(source):
        raise ValueError(f"Source file does not exist: {source}")
    

    # Keep path below the output directory from source and create a symlink in the target directory
    sub_path = os.path.relpath(source, target_dir)
    # target = os.path.join(target_dir, sub_path)
    print(f"Subpath: {sub_path}")

    filename = os.path.basename(source)
    target = sub_path # os.path.join( "../output" , filename)

    output_path = os.path.join(target_dir, filename)
    if os.path.exists(output_path):
        # os.remove(output_path)
        logger.info('Output file already exists in input directory. Skipping')
    else:
        logger.debug('Creating symlink from {} to {}'.format(source, output_path))
        os.symlink(target , output_path )


def run_diversity_analysis(base_dir, p_max_depth = 10000 , p_steps = 10000, p_sampling_depth = 500 , group_by=None, results = {}):

    # Run qiime diversity core-metrics-phylogenetic
    # qiime diversity core-metrics-phylogenetic \
    # --i-phylogeny $INPUT_DIR/rooted-tree.qza \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --p-sampling-depth 1100 \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --output-dir $OUTPUT_DIR/core-metrics-results

    input_dir = os.path.join(base_dir, 'input')
    output_dir = os.path.join(base_dir, 'output')

    core_metrics_output_dir = os.path.join(output_dir, 'core-metrics-results')

    # check if output directory already exists, skip if it does unless force is set to True
    if os.path.exists(core_metrics_output_dir):
        logger.info('Core metrics results directory already exists. Skipping')
    else:
        logger.info('Running core metrics')
        logger.debug("Options: --i-phylogeny {} --i-table {} --p-sampling-depth {} --m-metadata-file {} --output-dir {}".format(os.path.join(input_dir, 'rooted-tree.qza'), os.path.join(input_dir, 'table-dada2.qza'), p_sampling_depth, os.path.join(input_dir, 'mapping.txt'), core_metrics_output_dir))
        results['core_metrics'] = subprocess.run(['qiime', 'diversity', 'core-metrics-phylogenetic',
                                                 '--i-phylogeny', os.path.join(input_dir, 'rooted-tree.qza'),
                                                 '--i-table', os.path.join(input_dir, 'table-dada2.qza'),
                                                 '--p-sampling-depth', str(p_sampling_depth),
                                                 '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                 '--output-dir', core_metrics_output_dir])
        logger.debug('Core metrics output: {}'.format(results['core_metrics']))

    link_output(core_metrics_output_dir, input_dir)

    # Run qiime diversity alpha-group-significance on faith_pd_vector
    # qiime diversity alpha-group-significance \
    # --i-alpha-diversity $OUTPUT_DIR/core-metrics-results/faith_pd_vector.qza \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --o-visualization $OUTPUT_DIR/core-metrics-results/faith-pd-group-significance.qzv

    alpha_group_significance_output_name = 'faith-pd-group-significance.qzv'
    alpha_group_significance_output = os.path.join(core_metrics_output_dir, alpha_group_significance_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(alpha_group_significance_output):
        logger.info('Alpha group significance output already exists. Skipping')
    else:
        logger.info('Running alpha group significance')
        logger.debug("Options: --i-alpha-diversity {} --m-metadata-file {} --o-visualization {}".format(os.path.join(core_metrics_output_dir, 'faith_pd_vector.qza'), os.path.join(input_dir, 'mapping.txt'), alpha_group_significance_output))
        results['alpha_group_significance'] = subprocess.run(['qiime', 'diversity', 'alpha-group-significance',
                                                             '--i-alpha-diversity', os.path.join(core_metrics_output_dir, 'faith_pd_vector.qza'),
                                                             '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                             '--o-visualization', alpha_group_significance_output])
        logger.debug('Alpha group significance output: {}'.format(results['alpha_group_significance']))


        logger.debug('Alpha group significance output: {}'.format(results['alpha_group_significance']))

        if results['alpha_group_significance'].returncode != 0:
            logger.error('Error running alpha group significance')
            logger.error(results['alpha_group_significance'])
            logger.info('Exiting alpha diveristy analysis')
            return

    link_output(alpha_group_significance_output, input_dir)


    # Run qiime diversity alpha-group-significance on shannon_vector
    # qiime diversity alpha-group-significance \
    # --i-alpha-diversity $OUTPUT_DIR/core-metrics-results/shannon_vector.qza \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --o-visualization $OUTPUT_DIR/core-metrics-results/shannon-group-significance.qzv

    shannon_group_significance_output_name = 'shannon-group-significance.qzv'
    shannon_group_significance_output = os.path.join(core_metrics_output_dir, shannon_group_significance_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(shannon_group_significance_output):
        logger.info('Shannon group significance output already exists. Skipping')
    else:
        logger.info('Running shannon group significance')
        logger.debug("Options: --i-alpha-diversity {} --m-metadata-file {} --o-visualization {}".format(os.path.join(core_metrics_output_dir, 'shannon_vector.qza'), os.path.join(input_dir, 'mapping.txt'), shannon_group_significance_output))
        results['shannon_group_significance'] = subprocess.run(['qiime', 'diversity', 'alpha-group-significance',
                                                               '--i-alpha-diversity', os.path.join(core_metrics_output_dir, 'shannon_vector.qza'),
                                                               '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                               '--o-visualization', shannon_group_significance_output])
        logger.debug('Shannon group significance output: {}'.format(results['shannon_group_significance']))

    link_output(shannon_group_significance_output, input_dir)

    # Run qiime diversity alpha-group-significance on evenness_vector
    # qiime diversity alpha-group-significance \
    # --i-alpha-diversity $OUTPUT_DIR/core-metrics-results/evenness_vector.qza \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --o-visualization $OUTPUT_DIR/core-metrics-results/evenness-group-significance.qzv

    evenness_group_significance_output_name = 'evenness-group-significance.qzv'
    evenness_group_significance_output = os.path.join(core_metrics_output_dir, evenness_group_significance_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(evenness_group_significance_output):
        logger.info('Evenness group significance output already exists. Skipping')
    else:
        logger.info('Running evenness group significance')
        logger.debug("Options: --i-alpha-diversity {} --m-metadata-file {} --o-visualization {}".format(os.path.join(core_metrics_output_dir, 'evenness_vector.qza'), os.path.join(input_dir, 'mapping.txt'), evenness_group_significance_output))
        results['evenness_group_significance'] = subprocess.run(['qiime', 'diversity', 'alpha-group-significance',
                                                                '--i-alpha-diversity', os.path.join(core_metrics_output_dir, 'evenness_vector.qza'),
                                                                '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                                '--o-visualization', evenness_group_significance_output])
        logger.debug('Evenness group significance output: {}'.format(results['evenness_group_significance']))

    link_output(evenness_group_significance_output, input_dir)
    



    # Run qiime diversity alpha-rarefaction
    # qiime diversity alpha-rarefaction \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --i-phylogeny $INPUT_DIR/rooted-tree.qza \
    # --p-max-depth 1100 \
    # --p-steps 10 \
    # --output-dir $OUTPUT_DIR/alpha-rarefaction-results

    alpha_rarefaction_output_dir = os.path.join(output_dir, 'alpha-rarefaction-results')

    # check if output directory already exists, skip if it does unless force is set to True
    if os.path.exists(alpha_rarefaction_output_dir):
        logger.info('Alpha rarefaction results directory already exists. Skipping')
    else:
        logger.info('Running alpha rarefaction')
        logger.debug("Options: --i-table {} --i-phylogeny {} --p-max-depth {} --p-steps {} --output-dir {}".format(os.path.join(input_dir, 'table-dada2.qza'), os.path.join(input_dir, 'rooted-tree.qza'), p_max_depth, p_steps, alpha_rarefaction_output_dir))
        results['alpha_rarefaction'] = subprocess.run(['qiime', 'diversity', 'alpha-rarefaction',
                                                     '--i-table', os.path.join(input_dir, 'table-dada2.qza'),
                                                     '--i-phylogeny', os.path.join(input_dir, 'rooted-tree.qza'),
                                                     '--p-max-depth', str(p_max_depth),
                                                     '--p-steps', str(p_steps),
                                                     '--output-dir', alpha_rarefaction_output_dir])
        logger.debug('Alpha rarefaction output: {}'.format(results['alpha_rarefaction']))

    link_output(alpha_rarefaction_output_dir, input_dir)

    # Run qiime diversity beta-group-significance
    # qiime diversity beta-group-significance \
    # --i-distance-matrix $OUTPUT_DIR/core-metrics-results/unweighted_unifrac_distance_matrix.qza \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --m-metadata-column BodySite \
    # --o-visualization $OUTPUT_DIR/core-metrics-results/unweighted-unifrac-body-site-significance.qzv \
    # --p-pairwise

    beta_group_significance_output_name = 'unweighted-unifrac-body-site-significance.qzv'
    beta_group_significance_output = os.path.join(core_metrics_output_dir, beta_group_significance_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if group_by is not None:
        if os.path.exists(beta_group_significance_output):
            logger.info('Beta group significance output already exists. Skipping')
        else:
            logger.info('Running beta group significance')
            logger.debug("Options: --i-distance-matrix {} --m-metadata-file {} --m-metadata-column BodySite --o-visualization {} --p-pairwise".format(os.path.join(core_metrics_output_dir, 'unweighted_unifrac_distance_matrix.qza'), os.path.join(input_dir, 'mapping.txt'), beta_group_significance_output))
            results['beta_group_significance'] = subprocess.run(['qiime', 'diversity', 'beta-group-significance',
                                                                '--i-distance-matrix', os.path.join(core_metrics_output_dir, 'unweighted_unifrac_distance_matrix.qza'),
                                                                '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                                '--m-metadata-column', group_by,
                                                                '--o-visualization', beta_group_significance_output,
                                                                '--p-pairwise'])
            logger.debug('Beta group significance output: {}'.format(results['beta_group_significance']))

        link_output(beta_group_significance_output, input_dir)
    else:
        logger.info('No group by column specified. Skipping beta group significance')

    # Run qiime diversity pcoa


def run_phylogeny_analysis(base_dir, results = {}):

    input_dir = os.path.join(base_dir, 'input')
    output_dir = os.path.join(base_dir, 'output')

    # Run qiime phylogeny align-to-tree-mafft-fasttree

    # qiime phylogeny align-to-tree-mafft-fasttree \
    # --i-sequences $INPUT_DIR/rep-seqs-dada2.qza \
    # --o-alignment $OUTPUT_DIR/aligned-rep-seqs.qza \
    # --o-masked-alignment $OUTPUT_DIR/masked-aligned-rep-seqs.qza \
    # --o-tree $OUTPUT_DIR/unrooted-tree.qza \
    # --o-rooted-tree $OUTPUT_DIR/rooted-tree.qza

    aligned_output_name = 'aligned-rep-seqs.qza'
    masked_aligned_output_name = 'masked-aligned-rep-seqs.qza'
    unrooted_tree_output_name = 'unrooted-tree.qza'
    rooted_tree_output_name = 'rooted-tree.qza'
    
    aligned_output = os.path.join(output_dir, aligned_output_name)
    masked_aligned_output = os.path.join(output_dir, masked_aligned_output_name)
    unrooted_tree_output = os.path.join(output_dir, unrooted_tree_output_name)
    rooted_tree_output = os.path.join(output_dir, rooted_tree_output_name)

    # check if outputs already exist, skip if they do unless force is set to True
    if os.path.exists(aligned_output) and os.path.exists(masked_aligned_output) and os.path.exists(unrooted_tree_output) and os.path.exists(rooted_tree_output):
        logger.info('Phylogeny outputs already exist. Skipping')
    else:
        logger.info('Running phylogeny')
        logger.debug("Options: --i-sequences {} --o-alignment {} --o-masked-alignment {} --o-tree {} --o-rooted-tree {}".format(os.path.join(input_dir, 'rep-seqs-dada2.qza'), aligned_output, masked_aligned_output, unrooted_tree_output, rooted_tree_output))
        results['phylogeny'] = subprocess.run(['qiime', 'phylogeny', 'align-to-tree-mafft-fasttree',
                                             '--i-sequences', os.path.join(input_dir, 'rep-seqs-dada2.qza'),
                                             '--o-alignment', aligned_output,
                                             '--o-masked-alignment', masked_aligned_output,
                                             '--o-tree', unrooted_tree_output,
                                             '--o-rooted-tree', rooted_tree_output])
        logger.debug('Phylogeny output: {}'.format(results['phylogeny']))

    link_output(aligned_output, input_dir)
    link_output(masked_aligned_output, input_dir)
    link_output(unrooted_tree_output, input_dir)
    link_output(rooted_tree_output, input_dir)

    # Run qiime diversity alpha-rarefaction

    # qiime diversity alpha-rarefaction \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --i-phylogeny $OUTPUT_DIR/rooted-tree.qza \
    # --p-max-depth 1100 \
    # --p-steps 10 \
    # --output-dir $OUTPUT_DIR/alpha-rarefaction-results

    alpha_rarefaction_output_dir = os.path.join(output_dir, 'alpha-rarefaction-results')

    # check if output directory already exists, skip if it does unless force is set to True
    if os.path.exists(alpha_rarefaction_output_dir):
        logger.info('Alpha rarefaction results directory already exists. Skipping')
    else:
        logger.info('Running alpha rarefaction')
        logger.debug("Options: --i-table {} --i-phylogeny {} --p-max-depth 1100 --p-steps 10 --output-dir {}".format(os.path.join(input_dir, 'table-dada2.qza'), rooted_tree_output, alpha_rarefaction_output_dir))
        results['alpha_rarefaction'] = subprocess.run(['qiime', 'diversity', 'alpha-rarefaction',
                                                     '--i-table', os.path.join(input_dir, 'table-dada2.qza'),
                                                     '--i-phylogeny', rooted_tree_output,
                                                     '--p-max-depth', '1100',
                                                     '--p-steps', '10',
                                                     '--output-dir', alpha_rarefaction_output_dir])
        logger.debug('Alpha rarefaction output: {}'.format(results['alpha_rarefaction']))

    link_output(alpha_rarefaction_output_dir, input_dir)


    # Run qiime feature-table tabulate-seqs

    # qiime feature-table tabulate-seqs \
    # --i-data $INPUT_DIR/rep-seqs-dada2.qza \
    # --o-visualization $OUTPUT_DIR/rep-seqs.qzv

    rep_seqs_output_name = 'rep-seqs.qzv'
    rep_seqs_output = os.path.join(output_dir, rep_seqs_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(rep_seqs_output):
        logger.info('Rep seqs output already exists. Skipping')
    else:
        logger.info('Running rep seqs')
        logger.debug("Options: --i-data {} --o-visualization {}".format(os.path.join(input_dir, 'rep-seqs-dada2.qza'), rep_seqs_output))
        results['rep_seqs'] = subprocess.run(['qiime', 'feature-table', 'tabulate-seqs',
                                            '--i-data', os.path.join(input_dir, 'rep-seqs-dada2.qza'),
                                            '--o-visualization', rep_seqs_output])
        logger.debug('Rep seqs output: {}'.format(results['rep_seqs']))

    link_output(rep_seqs_output, input_dir)

    # Run qiime feature-classifier classify-sklearn

    # qiime feature-classifier classify-sklearn \
    # --i-classifier $INPUT_DIR/gg-13-8-99-515-806-nb-classifier.qza \
    # --i-reads $INPUT_DIR/rep-seqs-dada2.qza \
    # --o-classification $OUTPUT_DIR/taxonomy.qza

    taxonomy_output_name = 'taxonomy.qza'
    taxonomy_output = os.path.join(output_dir, taxonomy_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(taxonomy_output):
        logger.info('Taxonomy output already exists. Skipping')
    else:
        logger.info('Running taxonomy')
        logger.debug("Options: --i-classifier {} --i-reads {} --o-classification {}".format(os.path.join(input_dir, 'gg-13-8-99-515-806-nb-classifier.qza'), os.path.join(input_dir, 'rep-seqs-dada2.qza'), taxonomy_output))
        results['taxonomy'] = subprocess.run(['qiime', 'feature-classifier', 'classify-sklearn',
                                            '--i-classifier', os.path.join(input_dir, 'gg-13-8-99-515-806-nb-classifier.qza'),
                                            '--i-reads', os.path.join(input_dir, 'rep-seqs-dada2.qza'),
                                            '--o-classification', taxonomy_output])
        logger.debug('Taxonomy output: {}'.format(results['taxonomy']))

    link_output(taxonomy_output, input_dir)

    # Run qiime metadata tabulate

    # qiime metadata tabulate \
    # --m-input-file $OUTPUT_DIR/taxonomy.qza \
    # --o-visualization $OUTPUT_DIR/taxonomy.qzv

    taxonomy_viz_output_name = 'taxonomy.qzv'
    taxonomy_viz_output = os.path.join(output_dir, taxonomy_viz_output_name)


    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(taxonomy_viz_output):
        logger.info('Taxonomy viz output already exists. Skipping')
    else:
        logger.info('Running taxonomy viz')
        logger.debug("Options: --m-input-file {} --o-visualization {}".format(taxonomy_output, taxonomy_viz_output))
        results['taxonomy_viz'] = subprocess.run(['qiime', 'metadata', 'tabulate',
                                                '--m-input-file', taxonomy_output,
                                                '--o-visualization', taxonomy_viz_output])
        logger.debug('Taxonomy viz output: {}'.format(results['taxonomy_viz']))

    link_output(taxonomy_viz_output, input_dir)

    # Run qiime taxa barplot
    
    # qiime taxa barplot \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --i-taxonomy $OUTPUT_DIR/taxonomy.qza \
    # --m-metadata-file $INPUT_DIR/mapping.txt \
    # --o-visualization $OUTPUT_DIR/taxa-bar-plots.qzv

    taxa_barplot_output_name = 'taxa-bar-plots.qzv'
    taxa_barplot_output = os.path.join(output_dir, taxa_barplot_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(taxa_barplot_output):
        logger.info('Taxa barplot output already exists. Skipping')
    else:
        logger.info('Running taxa barplot')
        logger.debug("Options: --i-table {} --i-taxonomy {} --m-metadata-file {} --o-visualization {}".format(os.path.join(input_dir, 'table-dada2.qza'), taxonomy_output, os.path.join(input_dir, 'mapping.txt'), taxa_barplot_output))
        results['taxa_barplot'] = subprocess.run(['qiime', 'taxa', 'barplot',
                                                '--i-table', os.path.join(input_dir, 'table-dada2.qza'),
                                                '--i-taxonomy', taxonomy_output,
                                                '--m-metadata-file', os.path.join(input_dir, 'mapping.txt'),
                                                '--o-visualization', taxa_barplot_output])
        logger.debug('Taxa barplot output: {}'.format(results['taxa_barplot']))

    link_output(taxa_barplot_output, input_dir)

    # Run qiime feature-table summarize

    # qiime feature-table summarize \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --o-visualization $OUTPUT_DIR/table.qzv \
    # --m-sample-metadata-file $INPUT_DIR/mapping.txt





def run_relative_abundance_of_taxonomy( base_dir , results = {}):
    results = {}

    input_dir = os.path.join(base_dir, 'input')
    output_dir = os.path.join(base_dir, 'output')

    levels = ['1', '2', '3', '4', '5', '6', '7']


    for level in levels:

        #     qiime taxa collapse \
        #   --i-table feature-table.qza \
        #   --i-taxonomy taxonomy.qza \
        #   --p-level 2 \
        #   --o-collapsed-table phyla-table.qza 
        # Where feature-table.qza is from output of dada2/deblur and the taxonomy.qza file comes from the classifier I've linked above.
        # Now we will convert this new frequency table to relative-frequency:

        phyla_table_output_name = f'phyla-table.{level}.qza'


        if not os.path.exists(os.path.join(input_dir, "table-dada2.qza")):
            raise ValueError('Feature table not found in input directory')
        if not os.path.exists(os.path.join(input_dir, 'taxonomy.qza')):
            raise ValueError('Taxonomy file not found in input directory')
        
        if os.path.exists(os.path.join(output_dir, f"phyla-table.{level}.qza")):
            logger.info('Phyla table already exists. Skipping')
        else:
            logger.info('Running taxa collapse')
            results['taxa_collapse'] = subprocess.run(['qiime', 'taxa', 'collapse',
                                                    '--i-table', os.path.join(input_dir, 'table-dada2.qza'),
                                                    '--i-taxonomy', os.path.join(input_dir, 'taxonomy.qza'),
                                                    '--p-level', '2',
                                                    '--o-collapsed-table', os.path.join(output_dir, phyla_table_output_name )])
            logger.debug('Taxa collapse output: {}'.format(results['taxa_collapse']))

        link_output(os.path.join(output_dir, phyla_table_output_name), input_dir)    

        # qiime feature-table relative-frequency \
        # --i-table phyla-table.qza \
        # --o-realtive-frequency-table rel-phyla-table.qza
        # This new artifact now has the relative-abundances we want. To get this into a text file we first export the data which is in biom format:

        rel_phyla_table = f'rel-phyla-table.{level}.qza'

        if os.path.exists(os.path.join(output_dir, rel_phyla_table)):
            logger.info('Relative frequency table already exists. Skipping')
        else:
            results['relative_frequency'] = subprocess.run(['qiime', 'feature-table', 'relative-frequency',
                                                            '--i-table', os.path.join(output_dir, phyla_table_output_name),
                                                            '--o-relative-frequency-table', os.path.join(output_dir, rel_phyla_table )])
            logger.debug('Relative frequency output: {}'.format(results['relative_frequency']))

        link_output(os.path.join(output_dir, rel_phyla_table), input_dir)

        # qiime tools export rel-phyla-table.qza \
        # --output-dir rel-table


        phyla_table_dir = os.path.join(output_dir, 'rel-phyla-table-level-{}'.format(level))
       
        results['export'] = subprocess.run(['qiime', 'tools', 'export', 
                                            '--input-path', os.path.join(output_dir, rel_phyla_table),
                                            '--output-path', os.path.join(output_dir, phyla_table_dir )])
        logger.debug('Export output: {}'.format(results['export']))

        link_output(os.path.join(output_dir, phyla_table_dir), input_dir)


        # We now have our new relative-frequency table in .biom format. Let's convert this to a text file that we can open easily:

        # # first move into the new directory
        # cd rel-table
        # # note that the table has been automatically labelled feature-table.biom
        # # You might want to change this filename for calrity
        # biom convert -i feature-table.biom -o rel-phyla-table.tsv --to-tsv

        if not os.path.exists(os.path.join(output_dir, phyla_table_dir, f'feature-table.biom')):
            logger.error('Feature table does not exists. Exiting')
            return
        
        if os.path.exists(os.path.join(output_dir, phyla_table_dir, f'rel-phyla-table.{level}.tsv')):
            logger.info('Relative phyla table already exists. Skipping')
        else:
            # os.chdir(os.path.join(output_dir, 'rel-table'))
            # results['biom_convert'] = subprocess.run(['biom', 'convert', '-i', 'feature-table.biom',
            #                                           '-o', 'rel-phyla-table.tsv', '--to-tsv'])
        

            results['biom_convert'] = subprocess.run(['biom', 'convert', 
                                                    '-i', os.path.join( input_dir , phyla_table_dir, 'feature-table.biom'),
                                                    '-o', os.path.join( output_dir , phyla_table_dir ,f'rel-phyla-table.{level}.tsv'), 
                                                    '--to-tsv'])
            
            logger.debug('Biom convert output: {}'.format(results['biom_convert']))

        link_output(os.path.join(output_dir, 'rel-table', 'rel-phyla-table.tsv'), input_dir)


def run_workflow(base_dir, p_trunc_len_f=0, p_trunc_len_r=0 , p_max_depth = 10000 , p_steps = 10000, p_sampling_depth = 10000, beta_group_significance_column=None , barcode_column_name='BarcodeSequence', group_by=None, force=False):  
    # Create output directory and raw data directory
  
    # check if the input directory exists
    if not os.path.exists(base_dir):
        raise ValueError('Input directory does not exist')
    
    results = {}
    
    input_dir = os.path.join(base_dir, 'input')
    output_dir = os.path.join(base_dir, 'output')


    import_input_dir = os.path.join(input_dir ,'raw_data')
    import_output_name = 'paired-end-demux.qza'
    import_output = os.path.join(output_dir, import_output_name)
    
    # Run qiime import
    #     qiime tools import \
    #       --type EMPPairedEndSequences \
    #       --input-path $RAW_DATA_DIR \
    #       --output-path $OUTPUT_DIR/paired-end-sequences.qza

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(import_output):
        logger.info(f'Import: {import_output_name} already exists. Skipping')
    else:
        logger.info('Running import on {}'.format(import_input_dir))
        logger.debug("Options: --type EMPPairedEndSequences --input-path {} --output-path {}".format(import_input_dir, import_output))
        results['import']=subprocess.run(['qiime', 'tools', 'import', 
                           '--type', 'EMPPairedEndSequences', 
                           '--input-path', import_input_dir, 
                           '--output-path', import_output ])

    # link the output to the input directory
    logger.debug('Staging import output to input directory: {}'.format(import_output))
    link_output(import_output, input_dir)

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
        logger.info('Running demux')
        logger.debug("Options: emp-paired --m-barcodes-file {} --m-barcodes-column barcode-sequence --p-rev-comp-mapping-barcodes --p-rev-comp-barcodes --i-seqs {} --o-per-sample-sequences {} --o-error-correction-details {}".format(os.path.join(input_dir, 'mapping.txt'), import_output_name, demux_output, demux_details_output))
        results['demux'] = subprocess.run(['qiime', 'demux', 'emp-paired',
                                            '--m-barcodes-file', os.path.join(input_dir, 'mapping.txt'),
                                            '--m-barcodes-column', 'BarcodeSequence', #'barcode-sequence',
                                            '--p-rev-comp-mapping-barcodes',
                                            '--p-rev-comp-barcodes',
                                            '--i-seqs', import_output,
                                            '--o-per-sample-sequences', demux_output,
                                            '--o-error-correction-details', demux_details_output])
    
    link_output(demux_output, input_dir)
    link_output(demux_details_output, input_dir)

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
        logger.info('Running demux summarize')
        logger.debug("Options: --i-data {} --o-visualization {}".format(demux_output, demux_viz_output))
        results['demux_viz'] = subprocess.run(['qiime', 'demux', 'summarize',
                                               '--i-data', demux_output,
                                               '--o-visualization', demux_viz_output])
        logger.debug('Demux visualization output: {}'.format(results['demux_viz']))
    
    link_output(demux_viz_output, input_dir)

    # Export the demux visualization
    # qiime tools export \
    # --input-path $OUTPUT_DIR/demux-full.qzv \
    # --output-path $OUTPUT_DIR/demux-full

    demux_viz_export_dir = os.path.join(output_dir, 'demux-full')

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(demux_viz_export_dir):
        logger.info('Demux visualization export directory already exists. Skipping')
    else:
        logger.info('Exporting demux visualization')
        logger.debug("Options: --input-path {} --output-path {}".format(demux_viz_output, demux_viz_export_dir))
        results['demux_viz_export'] = subprocess.run(['qiime', 'tools', 'export',
                                                      '--input-path', demux_viz_output,
                                                      '--output-path', demux_viz_export_dir])
        logger.debug('Demux visualization export output: {}'.format(results['demux_viz_export']))

    link_output(demux_viz_export_dir, input_dir)

    # Run qiime dada2 denoise-paired
    # qiime dada2 denoise-paired \
    # --i-demultiplexed-seqs $INPUT_DIR/demux-full.qza \
    # --p-trim-left-f 0 \
    # --p-trim-left-r 0 \
    # --p-trunc-len-f 150 \
    # --p-trunc-len-r 150 \
    # --o-representative-sequences $OUTPUT_DIR/rep-seqs-dada2.qza \
    # --o-table $OUTPUT_DIR/table-dada2.qza \
    # --o-denoising-stats $OUTPUT_DIR/stats-dada2.qza

    denoise_output_name = 'rep-seqs-dada2.qza'
    table_output_name = 'table-dada2.qza'
    stats_output_name = 'stats-dada2.qza'
    denoise_output = os.path.join(output_dir, denoise_output_name)
    table_output = os.path.join(output_dir, table_output_name)
    stats_output = os.path.join(output_dir, stats_output_name)

    # check if outputs already exist, skip if they do unless force is set to True
    if os.path.exists(denoise_output) and os.path.exists(table_output) and os.path.exists(stats_output):
        logger.info('Denoise outputs already exist. Skipping')
    else:
        logger.info('Running dada2 denoise paired')
        logger.debug("Options: --i-demultiplexed-seqs {} --p-trim-left-f 0 --p-trim-left-r 0 --p-trunc-len-f {} --p-trunc-len-r {} --o-representative-sequences {} --o-table {} --o-denoising-stats {}".format(demux_output, p_trunc_len_f, p_trunc_len_r, denoise_output, table_output, stats_output))
        results['denoise'] = subprocess.run(['qiime', 'dada2', 'denoise-paired',
                                            '--i-demultiplexed-seqs', demux_output,
                                            '--p-trim-left-f', '0',
                                            '--p-trim-left-r', '0',
                                            '--p-trunc-len-f', str(p_trunc_len_f),
                                            '--p-trunc-len-r', str(p_trunc_len_r),
                                            '--o-representative-sequences', denoise_output,
                                            '--o-table', table_output,
                                            '--o-denoising-stats', stats_output])
        logger.debug('Denoise output: {}'.format(results['denoise']))

    link_output(denoise_output, input_dir)
    link_output(table_output, input_dir)
    link_output(stats_output, input_dir)

    # Run summarize feature table
    # qiime feature-table summarize \
    # --i-table $INPUT_DIR/table-dada2.qza \
    # --o-visualization $OUTPUT_DIR/table-dada2.qzv \
    # --m-sample-metadata-file $INPUT_DIR/mapping.txt

    table_viz_output_name = 'table-dada2.qzv'
    table_viz_output = os.path.join(output_dir, table_viz_output_name)  

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(table_viz_output):
        logger.info('Table visualization output already exists. Skipping')
    else:
        logger.info('Running feature table summarize')
        logger.debug("Options: --i-table {} --o-visualization {} --m-sample-metadata-file {}".format(table_output, table_viz_output, os.path.join(input_dir, 'mapping.txt')))
        results['table_viz'] = subprocess.run(['qiime', 'feature-table', 'summarize',
                                              '--i-table', table_output,
                                              '--o-visualization', table_viz_output,
                                              '--m-sample-metadata-file', os.path.join(input_dir, 'mapping.txt')])
        logger.debug('Table visualization output: {}'.format(results['table_viz']))

    link_output(table_viz_output, input_dir)

    ### Run summarizing feature sequences
    # qiime feature-table tabulate-seqs \
    # --i-data $INPUT_DIR/rep-seqs-dada2.qza \
    # --o-visualization $OUTPUT_DIR/rep-seqs-dada2.qzv

    rep_seq_viz_output_name = 'rep-seqs-dada2.qzv'
    rep_seq_viz_output = os.path.join(output_dir, rep_seq_viz_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(rep_seq_viz_output):
        logger.info('Representative sequence visualization output already exists. Skipping')
    else:
        logger.info('Running feature table tabulate sequences')
        logger.debug("Options: --i-data {} --o-visualization {}".format(denoise_output, rep_seq_viz_output))
        results['rep_seq_viz'] = subprocess.run(['qiime', 'feature-table', 'tabulate-seqs',
                                                '--i-data', denoise_output,
                                                '--o-visualization', rep_seq_viz_output])
        logger.debug('Representative sequence visualization output: {}'.format(results['rep_seq_viz']))

    link_output(rep_seq_viz_output, input_dir)

    ### Run qiime metadata tabulate
    # qiime metadata tabulate \
    # --m-input-file $INPUT_DIR/stats-dada2.qza \
    # --o-visualization $OUTPUT_DIR/stats-dada2.qzv

    stats_viz_output_name = 'stats-dada2.qzv'
    stats_viz_output = os.path.join(output_dir, stats_viz_output_name)

    # check if output already exists, skip if it does unless force is set to True
    if os.path.exists(stats_viz_output):
        logger.info('Stats visualization output already exists. Skipping')
    else:
        logger.info('Running metadata tabulate')
        logger.debug("Options: --m-input-file {} --o-visualization {}".format(stats_output, stats_viz_output))
        results['stats_viz'] = subprocess.run(['qiime', 'metadata', 'tabulate',
                                              '--m-input-file', stats_output,
                                              '--o-visualization', stats_viz_output])
        logger.debug('Stats visualization output: {}'.format(results['stats_viz']))

    link_output(stats_viz_output, input_dir)


    run_phylogeny_analysis(base_dir)
    run_diversity_analysis(base_dir, p_max_depth, p_steps, p_sampling_depth , group_by=beta_group_significance_column)
    run_relative_abundance_of_taxonomy(base_dir)


    logger.info('Workflow complete')
    # Run qiime metadata tabulate



# Create a function which executes the qiime scripts from https://forum.qiime2.org/t/relative-abundances-of-taxonomy-analysis/4939/6
# Start with the qiime taxa collapse script
# def taxa_collapse(input_dir, output_dir):
#     # qiime taxa collapse \
#     # --i-table $INPUT_DIR/table.qza \
#     # --i-taxonomy $INPUT_DIR/taxonomy.qza \
#     # --p-level 6 \
#     # --o-collapsed-table $OUTPUT_DIR/collapsed-table.qza
#     logger.info('Running taxa collapse')
#     results['taxa_collapse'] = subprocess.run(['qiime', 'taxa', 'collapse',
#                                                '--i-table', os.path.join(input_dir, 'table.qza'),
#                                                '--i-taxonomy', os.path.join(input_dir, 'taxonomy.qza'),
#                                                '--p-level', '6',
#                                                '--o-collapsed-table', os.path.join(output_dir, 'collapsed-table.qza')])
#     logger.debug('Taxa collapse output: {}'.format(results['taxa_collapse']))


# def relative_abundance_of_taxonomy( input_dir, output_dir):
#     results = {}

#     #     qiime taxa collapse \
#     #   --i-table feature-table.qza \
#     #   --i-taxonomy taxonomy.qza \
#     #   --p-level 2 \
#     #   --o-collapsed-table phyla-table.qza 
#     # Where feature-table.qza is from output of dada2/deblur and the taxonomy.qza file comes from the classifier I've linked above.
#     # Now we will convert this new frequency table to relative-frequency:

#     if not os.path.exists(os.path.join(input_dir, 'feature-table.qza')):
#         raise ValueError('Feature table not found in input directory')
#     if not os.path.exists(os.path.join(input_dir, 'taxonomy.qza')):
#         raise ValueError('Taxonomy file not found in input directory')
    
#     if os.path.exists(os.path.join(output_dir, 'phyla-table.qza')):
#         logger.info('Phyla table already exists. Skipping')
#     else:
#         logger.info('Running taxa collapse')
#         results['taxa_collapse'] = subprocess.run(['qiime', 'taxa', 'collapse',
#                                                 '--i-table', os.path.join(input_dir, 'feature-table.qza'),
#                                                 '--i-taxonomy', os.path.join(input_dir, 'taxonomy.qza'),
#                                                 '--p-level', '2',
#                                                 '--o-collapsed-table', os.path.join(output_dir, 'phyla-table.qza')])
#         logger.debug('Taxa collapse output: {}'.format(results['taxa_collapse']))

#     link_output(os.path.join(output_dir, 'phyla-table.qza'), input_dir)    

#     # qiime feature-table relative-frequency \
#     # --i-table phyla-table.qza \
#     # --o-realtive-frequency-table rel-phyla-table.qza
#     # This new artifact now has the relative-abundances we want. To get this into a text file we first export the data which is in biom format:

#     if os.path.exists(os.path.join(output_dir, 'rel-phyla-table.qza')):
#         logger.info('Relative frequency table already exists. Skipping')
#     else:
#         results['relative_frequency'] = subprocess.run(['qiime', 'feature-table', 'relative-frequency',
#                                                         '--i-table', os.path.join(output_dir, 'phyla-table.qza'),
#                                                         '--o-relative-frequency-table', os.path.join(output_dir, 'rel-phyla-table.qza')])
#         logger.debug('Relative frequency output: {}'.format(results['relative_frequency']))

#     link_output(os.path.join(output_dir, 'rel-phyla-table.qza'), input_dir)

#     # qiime tools export rel-phyla-table.qza \
#     # --output-dir rel-table

#     if os.path.exists(os.path.join(output_dir, 'rel-table')):
#         logger.info('Relative table directory already exists. Skipping')
#     else:
#         results['export'] = subprocess.run(['qiime', 'tools', 'export', os.path.join(output_dir, 'rel-phyla-table.qza'),
#                                             '--output-dir', os.path.join(output_dir, 'rel-table')])
#         logger.debug('Export output: {}'.format(results['export']))

#     link_output(os.path.join(output_dir, 'rel-table'), input_dir)


#     # We now have our new relative-frequency table in .biom format. Let's convert this to a text file that we can open easily:

#     # # first move into the new directory
#     # cd rel-table
#     # # note that the table has been automatically labelled feature-table.biom
#     # # You might want to change this filename for calrity
#     # biom convert -i feature-table.biom -o rel-phyla-table.tsv --to-tsv

#     if not os.path.exists(os.path.join(output_dir, 'rel-table', 'feature-table.biom')):
#         logger.error('Feature table does not exists. Exiting')
#         return
    
#     if os.path.exists(os.path.join(output_dir, 'rel-table', 'rel-phyla-table.tsv')):
#         logger.info('Relative phyla table already exists. Skipping')
#     else:
#         # os.chdir(os.path.join(output_dir, 'rel-table'))
#         # results['biom_convert'] = subprocess.run(['biom', 'convert', '-i', 'feature-table.biom',
#         #                                           '-o', 'rel-phyla-table.tsv', '--to-tsv'])
#         logger.debug('Biom convert output: {}'.format(results['biom_convert']))

#         results['biom_convert'] = subprocess.run(['biom', 'convert', 
#                                                   '-i', os.path.join( input_dir , "rel-table", 'feature-table.biom'),
#                                                   '-o', os.path.join( outputdir , "rel-table" ,'rel-phyla-table.tsv'), 
#                                                   '--to-tsv'])


#     link_output(os.path.join(output_dir, 'rel-table', 'rel-phyla-table.tsv'), input_dir)







def run_tool(name, args):
    # Run a QIIME tool with the given arguments
    # qiime <name> <args>
    logger.info('Running tool {}'.format(name))
    logger.debug('Arguments: {}'.format(args))
    results = subprocess.run(['qiime', 'tool' , name] + args)
    logger.debug('Results: {}'.format(results))



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

    # Tool qiime subparser
    tool_parser = subparsers.add_parser('tool', help='Run QIIME tool')
    # collect all arguments in a list
    tool_parser.add_argument('name', type=str, help='Name of the tool')
    tool_parser.add_argument('args', nargs=argparse.REMAINDER  , default=["--help"] , help='Arguments for the tool')

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
    workflow_parser.add_argument('--p-max-depth', type=int, default=10000, help="Maximum depth for alpha rarefaction")
    workflow_parser.add_argument('--p-steps', type=int, default=10000, help="Steps for alpha rarefaction")
    workflow_parser.add_argument('--p-sampling-depth', type=int, default=10000, help="Sampling depth for alpha rarefaction")
    workflow_parser.add_argument('--beta-diversity-group-by', type=str, default=None, help="Meta data column to group by for beta diversity analysis")
    workflow_parser.add_argument('--barcode_column_name', default="barcode-sequence", help='Barcode column name in the mapping file')    




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
            run_workflow(args.input_dir, args.p_trunc_len_f, args.p_trunc_len_r , args.p_max_depth, args.p_steps, args.p_sampling_depth , args.beta_diversity_group_by , barcode_column_name=args.barcode_column_name)
        else:
            raise ValueError('Invalid subcommand')
    elif args.command == 'tool':
            run_tool(args.name, args.args)
    else:
        logger.error('Invalid command {}'.format(args.command))
        # raise ValueError('Invalid command')


if __name__ == '__main__':
    main()
