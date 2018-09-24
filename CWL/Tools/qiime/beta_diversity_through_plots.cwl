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

stderr: beta_diversity_through_plots.error
stdout: beta_diversity_through_plots.out

baseCommand: beta_diversity_through_plots.py 
  #  -i otu_table.biom 
  #  -o bdiv_even100/ 
  #  -t rep_set.tre 
  #  -m Fasting_Map.txt -e 100

inputs:
  otu-table:
   type: File
   inputBinding:
     prefix: -i
  mapping:
    type: File
    inputBinding:
      prefix: -m 
  tree:
    type: File
    inputBinding:
      prefix: --tree_fp    



arguments:
    - valueFrom: beta_diversity
      prefix: -o

outputs:
  stderr:
    type: stderr
  stdout:
    type: stdout
  results:
    type: Directory
    outputBinding:  { glob: "beta_diversity" }   
  beta:
    type: Directory
    outputBinding: { glob: "beta_diversity" }   


s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"