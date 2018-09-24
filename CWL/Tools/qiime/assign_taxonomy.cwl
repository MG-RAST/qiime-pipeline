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

stderr: assign_taxonomy.error
stdout: assign_taxonomy.out

baseCommand: assign_taxonomy.py


inputs:
  fasta:
   type: File
   doc: fasta file
   inputBinding:
     prefix: --input_fasta_fp
  id_to_taxonomy:
    type: File?
    doc:  |
        Path to tab-delimited file mapping sequences to
        assigned taxonomy. Each assigned taxonomy is provided
        as a semicolon-separated list. For assignment with
        rdp, each assigned taxonomy must be exactly 6 levels
        deep. [default: /usr/local/lib/python2.7/dist-packages
        /qiime_default_reference/gg_13_8_otus/taxonomy/97_otu_
        taxonomy.txt]
    inputBinding:
      prefix: --id_to_taxonomy_fp
  reference_sequences:
    type: File?
    doc: |
      Path to reference sequences.  For assignment with
      blast, these are used to generate a blast database.
      For assignment with rdp, they are used as training
      sequences for the classifier. [default:
      /usr/local/lib/python2.7/dist-packages/qiime_default_r
    inputBinding:
      prefix: --reference_seqs_fp    


arguments:
  - valueFrom: taxonomy
    prefix: --output_dir




outputs:
  stdout:
    type: stdout
  stderr:
    type: stderr  
  results:
    type: Directory
    outputBinding: 
      glob: taxonomy
  id2taxonomy:
    type: File
    outputBinding:
      glob: taxonomy/*_rep_set_tax_assignments.txt
 

  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"
