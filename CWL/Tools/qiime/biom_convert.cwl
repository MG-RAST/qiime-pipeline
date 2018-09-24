#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1024  # just a default, could be lowered
  InlineJavascriptRequirement: {}
     
hints:
  DockerRequirement: 
    dockerPull: mgrast/qiime:1.0.20180919
  SoftwareRequirement:
    packages:
      qiime:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_008249" ]
        version: [ "1.9.1" ]

baseCommand: [ biom , convert]
# -i /make_otu_table_output/otu_table_gg.biom
# -o /convert_biom_output/otu_table_gg_from_biom_w_taxonomy.txt
# -b
# --header-key taxonomy
# --output-metadata-id



inputs:
  biom-table:
   type: File
   doc: BIOM table
   inputBinding:
     prefix: --input-fp
  output:
    type: string
    default: biom-table-output
    inputBinding:
      prefix: --output-fp
  biom-table-type:
    type:
      type: enum
      name: table_types
      symbols:
        - OTU table
        - Pathway table
        - Function table
        - Ortholog table
        - Gene table
        - Metabolite table
        - Taxon table
        - Table
      inputBinding:
        prefix: --table-type
    default: Table      
  include-observation:
    type: string?
    doc: |
      The observation metadata to include from the
      input BIOM table file when creating a tsv
      table file. By default no observation
      metadata will be included.     
    inputBinding:
      prefix: --header-key
  header-name-for-observation:
    type: string?
    doc: |
      The name to be given to the observation
      metadata column when creating a tsv table
      file if the column should be renamed.
    inputBinding:
      prefix: --output-metadata-id
  # convert-to-tsv:
  #   type: boolean?
  #   default: true
  #   inputBinding:
  #     prefix: --to-tsv
  # convert-to-json:
  #   type: boolean?
  #   inputBinding:
  #     prefix: --to-json
  convert-to:
    type:
      type: enum
      name: export-formats
      symbols:
        - json
        - tsv
      inputBinding:
        prefix: --to-
        separate: false  
    default: tsv     

  process-observation-metadata:
    type:
      - "null"
      - type: enum
        symbols: [taxonomy , naive , sc_separated]
        inputBinding:
          prefix: --process-obs-metadata

  
                                     




# arguments:
#   - valueFrom: biom-table-output
#     prefix: --output-fp




outputs:
  table:
    type: File
    outputBinding:
      glob: $(inputs.output)
 

  
  
$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "n/a"
