
# This script is a workflow for analyzing 16S rRNA gene sequences using QIIME2.

BASE_DIR=$1
SKIP=1
INPUT_DIR=$BASE_DIR/input
OUTPUT_DIR=$BASE_DIR/output
RELATIVE_OUTPUT_DIR=../output # Relative path to input directory from output directory
RAW_DATA_DIR=$BASE_DIR/input/raw-data

BARCODES_FILE=$INPUT_DIR/mapping.txt
BARCODES_FILE=$INPUT_DIR/mapping.tsv
#BARCODES_FILE=$INPUT_DIR/metadata.tsv

SAMPLING_DEPTH=1100
MAX_DEPTH_ALPHA_DIVERSITY=4000


echo "Importing data from $RAW_DATA_DIR"

if [ ! -f $OUTPUT_DIR/emp-paired-end-sequences.qza ] && [ $SKIP -le 2 ] 
then

time qiime tools import \
--type EMPPairedEndSequences \
--input-path $RAW_DATA_DIR \
--output-path $OUTPUT_DIR/emp-paired-end-sequences.qza

else
	echo "Skipping Import - file i$OUTPUT_DIR/emp-paired-end-sequences.qza exists"
fi

echo "Creating symbolic link to input directory for $OUTPUT_DIR/emp-paired-end-sequences.qza"
ln -s $RELATIVE_OUTPUT_DIR/emp-paired-end-sequences.qza $INPUT_DIR/emp-paired-end-sequences.qza

echo "Demultiplexing data"
echo "Using barcodes file: $BARCODES_FILE"

if [  ! -f  $OUTPUT_DIR/demux-full.qza ] && [ ! -f $OUTPUT_DIR/demux-details.qza ]
then

time qiime demux emp-paired \
--m-barcodes-file $BARCODES_FILE \
--m-barcodes-column barcode-sequence \
--p-rev-comp-mapping-barcodes \
--p-rev-comp-barcodes \
--i-seqs $INPUT_DIR/emp-paired-end-sequences.qza \
--o-per-sample-sequences $OUTPUT_DIR/demux-full.qza \
--o-error-correction-details $OUTPUT_DIR/demux-details.qza

else
	echo "Skipping demux"
fi

echo "Creating symbolic links to input directory for demux files"
ln -s $RELATIVE_OUTPUT_DIR/demux-full.qza $INPUT_DIR/demux-full.qza
ln -s $RELATIVE_OUTPUT_DIR/demux-details.qza $INPUT_DIR/demux-details.qza

echo "Summarizing demux data"

if [ ! -f $OUTPUT_DIR/demux-full.qzv ] 
then 
time qiime demux summarize \
--i-data $INPUT_DIR/demux-full.qza \
--o-visualization $OUTPUT_DIR/demux-full.qzv
else
	echo "Skipping demux summary"
fi


echo "Creating symbolic link to input directory for demux visualization"
ln -s $RELATIVE_OUTPUT_DIR/demux-full.qzv $INPUT_DIR/demux-full.qzv

echo "Extracting demux data"

if [ ! -d $OUTPUT_DIR/demux-full ] 
then

qiime tools extract \
--input-path $INPUT_DIR/demux-full.qzv \
--output-path $OUTPUT_DIR/demux-full

else
    echo "Skipping extract demux data"
fi

echo "Denoising data"

if [ ! -f $OUTPUT_DIR/table-dada2.qza ] && [ ! -f $OUTPUT_DIR/rep-seqs-dada2.qza ] && [ ! -f $OUTPUT_DIR/denoising-stats-dada2.qza ]
then

qiime dada2 denoise-paired \
--i-demultiplexed-seqs $INPUT_DIR/demux-full.qza \
--o-table $OUTPUT_DIR/table-dada2.qza \
--o-representative-sequences $OUTPUT_DIR/rep-seqs-dada2.qza \
--o-denoising-stats $OUTPUT_DIR/denoising-stats-dada2.qza \
--p-trunc-len-f 0 \
--p-trunc-len-r 0 
# --p-trim-left-f XXX \
# --p-trim-left-r XXX \
    
else
    echo "Skipping denoising"
fi



ln -s $RELATIVE_OUTPUT_DIR/table-dada2.qza $INPUT_DIR/table-dada2.qza
ln -s $RELATIVE_OUTPUT_DIR/rep-seqs-dada2.qza $INPUT_DIR/rep-seqs-dada2.qza
ln -s $RELATIVE_OUTPUT_DIR/denoising-stats-dada2.qza $INPUT_DIR/denoising-stats-dada2.qza

echo "Summarizing feature table"

if [ ! -f $OUTPUT_DIR/table-dada2.qzv ]
then

qiime feature-table summarize \
--i-table $INPUT_DIR/table-dada2.qza \
--m-sample-metadata-file $BARCODES_FILE \
--o-visualization $OUTPUT_DIR/table-dada2.qzv 

else
    echo "Skipping feature table summary"
fi

echo "Creating symbolic link to input directory for feature table visualization"
ln -s $RELATIVE_OUTPUT_DIR/table-dada2.qzv $INPUT_DIR/table-dada2.qzv

echo "Summarizing feature sequences"

if [ ! -f $OUTPUT_DIR/rep-seqs-dada2.qzv ]
then

qiime feature-table tabulate-seqs \
--i-data $INPUT_DIR/rep-seqs-dada2.qza \
--o-visualization $OUTPUT_DIR/rep-seqs-dada2.qzv

else
    echo "Skipping feature sequences summary"
fi

echo "Creating symbolic links to input directory for feature table and sequences visualizations"
ln -s $RELATIVE_OUTPUT_DIR/table-dada2.qzv $INPUT_DIR/table-dada2.qzv

echo "Metadata tabulate"

if [ ! -f $OUTPUT_DIR/denoising-stats-dada2.qzv ]
then
qiime metadata tabulate \
--m-input-file $INPUT_DIR/denoising-stats-dada2.qza \
--o-visualization $OUTPUT_DIR/denoising-stats-dada2.qzv
else
    echo "Skipping metadata tabulate"
fi

if [ ! -f $OUTPUT_DIR/aligned-rep-seqs.qza ] \
&& [ ! -f $OUTPUT_DIR/masked-aligned-rep-seqs.qza ] \
&& [ ! -f $OUTPUT_DIR/unrooted-tree.qza ] \
&& [ ! -f $OUTPUT_DIR/rooted-tree.qza ] 
then
qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences $INPUT_DIR/rep-seqs-dada2.qza \
--o-alignment $OUTPUT_DIR/aligned-rep-seqs.qza \
--o-masked-alignment $OUTPUT_DIR/masked-aligned-rep-seqs.qza \
--o-tree $OUTPUT_DIR/unrooted-tree.qza \
--o-rooted-tree $OUTPUT_DIR/rooted-tree.qza

else
    echo "Skipping phylogeny"
fi

ln -s $RELATIVE_OUTPUT_DIR/aligned-rep-seqs.qza $INPUT_DIR/aligned-rep-seqs.qza
ln -s $RELATIVE_OUTPUT_DIR/masked-aligned-rep-seqs.qza $INPUT_DIR/masked-aligned-rep-seqs.qza
ln -s $RELATIVE_OUTPUT_DIR/unrooted-tree.qza $INPUT_DIR/unrooted-tree.qza
ln -s $RELATIVE_OUTPUT_DIR/rooted-tree.qza $INPUT_DIR/rooted-tree.qza


echo "Core metrics phylogenetic"
if [ ! -d $OUTPUT_DIR/core-metrics-results ]
then


# use $SAMPLE_DEPTH for --p-sampling-depth
qiime diversity core-metrics-phylogenetic \
--i-phylogeny $INPUT_DIR/rooted-tree.qza \
--i-table $INPUT_DIR/table-dada2.qza \
--p-n-jobs-or-threads auto \
--p-sampling-depth 1 \
--m-metadata-file $BARCODES_FILE \
--output-dir $OUTPUT_DIR/core-metrics-results

else
    echo "Skipping core metrics phylogenetic"
fi

echo "Creating symbolic link to input directory for core metrics results"
ln -s $RELATIVE_OUTPUT_DIR/core-metrics-results $INPUT_DIR/core-metrics-results

echo "Alpha rarefaction"

# use $MAX_DEPTH_ALPHA_DIVERSITY for --p-max-depth
qiime diversity alpha-rarefaction \
--i-table $INPUT_DIR/table-dada2.qza \
--i-phylogeny $INPUT_DIR/rooted-tree.qza \
--p-max-depth 5 \
--p-steps 4 \
--m-metadata-file $BARCODES_FILE \
--o-visualization $OUTPUT_DIR/alpha-rarefaction.qzv


qiime diversity alpha-group-significance \
--i-alpha-diversity $INPUT_DIR/core-metrics-results/faith_pd_vector.qza \
--m-metadata-file $BARCODES_FILE \
--o-visualization $OUTPUT_DIR/core-metrics-results/faith-pd-group-significance.qzv

qiime diversity alpha-group-significance \
--i-alpha-diversity $INPUT_DIR/core-metrics-results/evenness_vector.qza \
--m-metadata-file $BARCODES_FILE \
--o-visualization $OUTPUT_DIR/core-metrics-results/evenness-group-significance.qzv


if [ ! -f $OUTPUT_DIR/core-metrics-results/observed-otus-group-significance.qzv ] && [ $METADTA_COLUMN=='']
then
qiime diversity beta-group-significance \
--i-distance-matrix $INPUT_DIR/core-metrics-results/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file $BARCODES_FILE \
--m-metadata-column $METADTA_COLUMN \
--o-visualization $OUTPUT_DIR/core-metrics-results/unweighted-unifrac-transect-name-significance.qzv \
--p-pairwise

else
    echo "Skipping beta group significance"
    echo "Metadata column not provided or file exists"
fi


qiime feature-classifier classify-sklearn \
--i-classifier $INPUT_DIR/gg-18-8-99-515-806-nb-classifier.qza \
--i-reads $INPUT_DIR/rep-seqs-dada2.qza \
--o-classification $OUTPUT_DIR/taxonomy.qza

qiime metadata tabulate \
--m-input-file $INPUT_DIR/taxonomy.qza \
--o-visualization $OUTPUT_DIR/taxonomy.qzv


qiime taxa barplot \
--i-table $INPUT_DIR/table-dada2.qza \
--i-taxonomy $INPUT_DIR/taxonomy.qza \
--m-metadata-file $BARCODES_FILE \
--o-visualization $OUTPUT_DIR/taxa-bar-plots.qzv

