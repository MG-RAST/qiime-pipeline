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

stderr: alpha_diversity.error
stdout: alpha_diversity.out

inputs:
  otu-table:
   type: File
   inputBinding:
     prefix: -i
  method:
    type: string[]
    default: [ chao1 , PD_whole_tree , shannon , observed_otus ]
    inputBinding:
      prefix: -m
      separate: false
      itemSeparator: ","
  tree:
    type: File
    inputBinding:
      prefix: --tree_path     

baseCommand: alpha_diversity.py 
  # -i otu_table.biom 
  # -m chao1,PD_whole_tree 
  # -o adiv_chao1_pd.txt 
  # -t rep_set.tre

arguments:
    - valueFrom: alpha_diversity.txt 
      prefix: -o

outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout
  alpha:
    type: File?
    outputBinding: { glob: "alpha_diversity.txt" }   


s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"