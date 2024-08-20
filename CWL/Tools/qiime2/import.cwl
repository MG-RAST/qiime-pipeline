cwlVersion: v1.2

# What type of CWL process we have in this document.
class: CommandLineTool
# This CommandLineTool executes the linux "echo" command-line tool.

requirements:
  - class: InlineJavascriptRequirement

hints:
  DockerRequirement: 
    dockerPull: quay.io/qiime2/amplicon:2024.5



baseCommand: qiime

arguments:
  - tools
  - import

stderr: import.err
stdout: import.out

# The inputs for this process.
inputs:
    semantic-type:
        type: string
        default: EMPPairedEndSequences
        inputBinding:
            prefix: --type
    input-path:
        type: Directory
        inputBinding:
            prefix: --input-path
    output-path:
        type: string
        default: import.sequences.qza
        inputBinding:
            prefix: --output-path

outputs: 
  stderr:
    type: stderr
  stdout:
    type: stdout
  artifact:
    type: File
    outputBinding:
        glob: $(inputs.output-path)