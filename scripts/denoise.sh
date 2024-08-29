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
    # --p-trim-left-r XXX
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