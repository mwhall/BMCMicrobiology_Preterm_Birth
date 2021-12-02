#!/bin/bash

# Download raw data resources
mkdir -p reads
cd reads
wget https://quoc.ca/static/preterm_birth_reads_passed.qza
cd ..

mkdir -p reference
cd reference
wget https://data.qiime2.org/2021.11/common/silva-138-99-nb-classifier.qza
cd ..

# Ensure your QIIME environment is loaded before running this script (i.e., conda activate qiime2-2021.11)

# We perform parallel analyses on the QC passed and QC failed read files
# Though they failed QC, they are worth including here for completeness, 
# especially since some of the placental samples are discussed in the manuscript

#This command imports the FASTQ files into a QIIME artifact
# Not needed if downloading .qza files directly
#qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' --input-path reads/PassedSamples/import_to_qiime --output-path reads_passed
#qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' --input-path reads/FailedSamples/import_to_qiime --output-path reads_failed

#Using DADA2 to analyze quality scores of 10 random samples
qiime demux summarize --p-n 10000 --i-data reads/preterm_birth_reads_passed.qza --o-visualization artifacts/qual_viz_passed
qiime demux summarize --p-n 10000 --i-data reads/preterm_birth_reads_failed.qza --o-visualization artifacts/qual_viz_failed

#Denoising with DADA2. Using quality score visualizations, you can choose trunc-len-f and trunc-len-r (note: sequences < trunc-len in length are discarded!)
qiime dada2 denoise-paired --i-demultiplexed-seqs reads/preterm_birth_reads_passed.qza --o-table artifacts/unfiltered_table_passed --o-representative-sequences artifacts/representative_sequences_passed --p-trunc-len-r 270 --p-trunc-len-f 280 --p-trim-left-f 12 --p-trim-left-r 12 --p-n-threads 4 --o-denoising-stats artifacts/denoise_stats_passed.qza --verbose
qiime dada2 denoise-paired --i-demultiplexed-seqs reads/preterm_birth_reads_failed.qza --o-table artifacts/unfiltered_table_failed --o-representative-sequences artifacts/representative_sequences_failed --p-trunc-len-r 270 --p-trunc-len-f 280 --p-trim-left-f 12 --p-trim-left-r 12 --p-n-threads 4 --o-denoising-stats artifacts/denoise_stats_failed.qza --verbose


qiime feature-classifier classify-sklearn --i-classifier silva-138-99-nb-classifier.qza --i-reads artifacts/representative_sequences_passed.qza --o-classification artifacts/taxonomy_passed
qiime feature-classifier classify-sklearn --i-classifier silva-138-99-nb-classifier.qza --i-reads artifacts/representative_sequences_failed.qza --o-classification artifacts/taxonomy_failed

#This visualization shows us the sequences/sample spread
qiime feature-table summarize --i-table artifacts/unfiltered_table_passed.qza --o-visualization artifacts/table_summary_passed
qiime feature-table summarize --i-table artifacts/unfiltered_table_failed.qza --o-visualization artifacts/table_summary_failed

#Taxa bar plots
qiime taxa barplot --i-table artifacts/unfiltered_table_passed.qza --i-taxonomy artifacts/taxonomy_passed.qza --m-metadata-file metadata/METADATA_passed.tsv --o-visualization artifacts/taxa-bar-plots_passed
qiime taxa barplot --i-table artifacts/unfiltered_table_failed.qza --i-taxonomy artifacts/taxonomy_failed.qza --m-metadata-file metadata/METADATA_failed.tsv --o-visualization artifacts/taxa-bar-plots_failed

#Steps for generating a phylogenetic tree
qiime alignment mafft --i-sequences artifacts/representative_sequences_passed.qza --o-alignment artifacts/aligned_representative_sequences_passed
qiime alignment mafft --i-sequences artifacts/representative_sequences_failed.qza --o-alignment artifacts/aligned_representative_sequences_failed

qiime alignment mask --i-alignment artifacts/aligned_representative_sequences_passed.qza --o-masked-alignment artifacts/masked_aligned_representative_sequences_passed
qiime alignment mask --i-alignment artifacts/aligned_representative_sequences_failed.qza --o-masked-alignment artifacts/masked_aligned_representative_sequences_failed

qiime phylogeny fasttree --i-alignment artifacts/masked_aligned_representative_sequences_passed.qza --o-tree artifacts/unrooted_tree_passed
qiime phylogeny fasttree --i-alignment artifacts/masked_aligned_representative_sequences_failed.qza --o-tree artifacts/unrooted_tree_failed

qiime phylogeny midpoint-root --i-tree artifacts/unrooted_tree_passed.qza --o-rooted-tree artifacts/rooted_tree_passed
qiime phylogeny midpoint-root --i-tree artifacts/unrooted_tree_failed.qza --o-rooted-tree artifacts/rooted_tree_failed

#Only do the following for successful samples

#Generate alpha/beta diversity measures at 10000 sequences/sample
#Also generates PCoA plots automatically
qiime diversity core-metrics-phylogenetic --i-phylogeny artifacts/rooted_tree_passed.qza --i-table artifacts/unfiltered_table_passed.qza --p-sampling-depth 2000 --output-dir artifacts/diversity_2000_passed --m-metadata-file metadata/METADATA_passed.tsv
qiime diversity core-metrics-phylogenetic --i-phylogeny artifacts/rooted_tree_failed.qza --i-table artifacts/unfiltered_table_failed.qza --p-sampling-depth 500 --output-dir artifacts/diversity_500_failed --m-metadata-file metadata/METADATA_failed.tsv

#Test for between-group differences
qiime diversity alpha-group-significance --i-alpha-diversity artifacts/diversity_2000_passed/faith_pd_vector.qza --m-metadata-file metadata/METADATA_passed.tsv --o-visualization artifacts/diversity_2000_passed/alpha_PD_significance
qiime diversity alpha-group-significance --i-alpha-diversity artifacts/diversity_2000_passed/shannon_vector.qza --m-metadata-file metadata/METADATA_passed.tsv --o-visualization artifacts/diversity_2000_passed/shannon_significance

#Alpha rarefaction curves show taxon accumulation as a function of sequence depth
qiime diversity alpha-rarefaction --i-table artifacts/unfiltered_table_passed.qza --p-max-depth 10000 --o-visualization artifacts/diversity_2000_passed/alpha_rarefaction.qzv --m-metadata-file metadata/METADATA_passed.tsv --i-phylogeny artifacts/rooted_tree_passed.qza

