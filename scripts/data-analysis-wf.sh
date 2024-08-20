
# This script is a workflow for analyzing 16S rRNA gene sequences using QIIME2.

BASE_DIR=$1
SKIP=1
INPUT_DIR=$BASE_DIR/input
OUTPUT_DIR=$BASE_DIR/output
RELATIVE_OUTPUT_DIR=../output # Relative path to input directory from output directory
RAW_DATA_DIR=$BASE_DIR/input/raw-data

BARCODES_FILE=$INPUT_DIR/mapping.txt
#BARCODES_FILE=$INPUT_DIR/metadata.tsv




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


qiime tools extract \
--input-path $INPUT_DIR/demux-full.qzv \
--output-path $OUTPUT_DIR/demux-full



echo "Denoising data"

qiime dada2 denoise-paired \
--i-demultiplexed-seqs $INPUT_DIR/demux-full.qza \
--o-table $OUTPUT_DIR/table-dada2.qza \
--o-representative-sequences $OUTPUT_DIR/rep-seqs-dada2.qza \
--o-denoising-stats $OUTPUT_DIR/denoising-stats-dada2.qza \
--p-trunc-len-f 0 \
--p-trunc-len-r 0 
# --p-trim-left-f XXX \
# --p-trim-left-r XXX \

exit 0


ln -s $RELATIVE_OUTPUT_DIR/table-dada2.qza $INPUT_DIR/table-dada2.qza
ln -s $RELATIVE_OUTPUT_DIR/rep-seqs-dada2.qza $INPUT_DIR/rep-seqs-dada2.qza
ln -s $RELATIVE_OUTPUT_DIR/denoising-stats-dada2.qza $INPUT_DIR/denoising-stats-dada2.qza

echo "Summarizing feature table"

qiime feature-table summarize \
--i-table $INPUT_DIR/table-dada2.qza \
--m-sample-metadata-file $BARCODES_FILE \
--o-visualization $INPUT_DIR/table-dada2.qzv 

echo "Summarizing feature sequences"

qiime feature-table tabulate-seqs \
--i-data $INPUT_DIR/rep-seqs-dada2.qza \
--o-visualization $OUTPUT_DIR/rep-seqs-dada2.qzv


qiime metadata tabulate \ 
--m-input-file $INPUT_DIR/denoising-stats-dada2.qza \
--o-visualization $OUTPUT_DIR/denoising-stats-dada2.qzv

exit 0

qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences rep-seqs-dada2.qza \
--o-alignment aligned-rep-seqs.qza \
--o-masked-alignment masked-aligned-rep-seqs.qza \
--o-tree unrooted-tree.qza \
--o-rooted-tree rooted-tree.qza

qiime diversity core-metrics-phylogenetic \ 
--i-phylogeny rooted-tree.qza\
--i-table table-dada2.qza \
--p-sampling-depth XXXX \ 		
--m-metadata-file sample-metadata.tsv \
--output-dir core-metrics-results

qiime diversity alpha-rarefaction \
--i-table table-dada2.qza \
--i-phylogeny rooted-tree.qza \
--p-max-depth XXXX \
--m-metadata-file sample-metadata.tsv \
--o-visualization alpha-rarefaction.qzv


qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
--m-metadata-file sample-metadata.tsv \
--o-visualization core-metrics-results/faith-pd-group-significance.qzv

qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/evenness_vector.qza \
--m-metadata-file sample-metadata.tsv \
--o-visualization core-metrics-results/evenness-group-significance.qzv

qiime diversity beta-group-significance \
--i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file sample-metadata.tsv \
--m-metadata-column transect-name \
--o-visualization core-metrics-results/unweighted-unifrac-transect-name-significance.qzv \ 
--p-pairwise


qiime feature-classifier classify-sklearn \
--i-classifier gg-18-8-99-515-806-nb-classifier.qza \
--i-reads rep-seqs-dada2.qza \
--o-classification taxonomy.qza

qiime metadata tabulate \
--m-input-file taxonomy.qza \
--o-visualization taxonomy.qzv


qiime taxa barplot \
--i-table table-dada2.qza \
--i-taxonomy taxonomy.qza \
--m-metadata-file sample-metadata.tsv \
--o-visualization taxa-bar-plots.qzv

