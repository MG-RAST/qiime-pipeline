#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered

hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]

stderr: split_libraries_fastq.error
stdout: split_libraries_fastq.out

inputs:
  reads:
   type: File[]
   inputBinding:
     prefix: -i
     itemSeparator: "," 
  mapping:
    type: File
    inputBinding:
      prefix: -m
  index:
    type: File[]
    inputBinding:
      prefix: -b
      itemSeparator: ","   
  reverse-complement-barcode:
    type: boolean?
    doc: Reverse complement barcode reads before lookup , default = False
    inputBinding:
      prefix: --rev_comp_barcode 
  store_qual_scores:
    type: boolean?
    default: false
    inputBinding:
      prefix: --store_qual_scores
  store_demultiplexed_fastq:
    type: boolean?
    default: false
    inputBinding:
      prefix: --store_demultiplexed_fastq 

baseCommand: split_libraries_fastq.py

arguments:
    - valueFrom: demultiplexed
      prefix: -o
    - valueFrom: "12"
      prefix: --barcode_type
    - valueFrom: "0"
      prefix: -n   



outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout
  demultiplexed:
    type: Directory
    outputBinding: { glob: "demultiplexed" }   
  histogram:
    type: File
    outputBinding: { glob: "demultiplexed/histograms.txt" }
  fasta: 
    type: File
    outputBinding: { glob: "demultiplexed/seqs.fna" }  
  log:
    type: File
    outputBinding: { glob: "demultiplexed/split_library_log.txt" }
  

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"
