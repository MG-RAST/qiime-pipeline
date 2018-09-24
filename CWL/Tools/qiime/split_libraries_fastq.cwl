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
   type: File
   inputBinding:
     prefix: -i
  mapping:
    type: File
    inputBinding:
      prefix: -m
  index:
    type: File
    inputBinding:
      prefix: -b     

baseCommand: split_libraries_fastq.py

arguments:
    - valueFrom: demultiplexed
      prefix: -o
    - valueFrom: "12"
      prefix: --barcode_type  



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