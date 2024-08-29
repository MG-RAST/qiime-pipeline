# This script is a workflow for analyzing 16S rRNA gene sequences using QIIME2.
BASE_DIR=$1
INPUT_DIR=$BASE_DIR/input
OUTPUT_DIR=$BASE_DIR/output
RELATIVE_OUTPUT_DIR=../output # Relative path to input directory from output directory
RAW_DATA_DIR=$BASE_DIR/input/raw-data
BARCODES_FILE=$INPUT_DIR/mapping.tsv
#BARCODES_FILE=$INPUT_DIR/metadata.tsv
SAMPLING_DEPTH=1100
MAX_DEPTH_ALPHA_DIVERSITY=4000

echo "Importing data from $RAW_DATA_DIR"
if [ ! -f $OUTPUT_DIR/emp-paired-end-sequences.qza ]
then
    qiime tools import \
    --type EMPPairedEndSequences \
    --input-path $RAW_DATA_DIR \
    --output-path $OUTPUT_DIR/emp-paired-end-sequences.qza
else
    echo "Skipping Import - file $OUTPUT_DIR/emp-paired-end-sequences.qza exists"
fi

echo "Creating symbolic link to input directory for $OUTPUT_DIR/emp-paired-end-sequences.qza"
ln -s $RELATIVE_OUTPUT_DIR/emp-paired-end-sequences.qza $INPUT_DIR/emp-paired-end-sequences.qza

echo "Demultiplexing data"
echo "Using barcodes file: $BARCODES_FILE"
if [  ! -f  $OUTPUT_DIR/demux-full.qza ] && [ ! -f $OUTPUT_DIR/demux-details.qza ]
then
    qiime demux emp-paired \
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
    qiime demux summarize \
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
