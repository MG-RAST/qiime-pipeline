#!/usr/bin/env python

import os
import sys


# Create functions for 
# 1. Testing if file is in tsv format
# 2. Testing if the header row has a valid string in every column
# 3. Testing if at least one column has more than one unique value but less than column length


def test_tsv_format(file):
    if not ( file.endswith('.tsv') or file.endswith('.txt') ):
        print("Error: file is not in tsv format")
        sys.exit(1)

    # Test if every line is tab separated and has the same number of columns
    max_len = None

    with open(file, 'r') as f:
        for line in f:
            if not line.endswith('\n'):
                print("Error: file is not in tsv format")
                sys.exit(1)

            current_len = len(line.split('\t'))
            if not max_len == None and current_len != max_len:
                print("Error: lines have different number of columns")
                sys.exit(1)
            if max_len == None:
                max_len = current_len



def test_header_row(file):
    with open(file, 'r') as f:
        header = f.readline()
        if not header:
            print("Error: file is empty")
            sys.exit(1)

        if not all(header.split('\t')):
            print("Error: header row has empty columns")
            sys.exit(1)

def test_unique_values(file):
    with open(file, 'r') as f:
        header = f.readline().split('\t')
        for i in range(1, len(header)):
            unique_values = set()
            for line in f:
                line = line.split('\t')
                unique_values.add(line[i])
            if len(unique_values) < 2 or len(unique_values) == len(header):
                print("Error: column " + header[i] + " has less than 2 unique values or all unique values")
                sys.exit(1)

def main():
    # Get file from command line

    if len(sys.argv) < 2:
        print("Usage: python3 check_metadata.py <file>")
        sys.exit(1)
    
    file = sys.argv[1]
    if not os.path.isfile(file):
        print("Error: file not found")
        sys.exit(1)

    test_tsv_format(file)
    test_header_row(file)
    test_unique_values(file)
    print("File is in tsv format, header row has valid strings, and at least one column has more than one unique value but less than column length")





# if main execute the main function
if __name__ == "__main__":
    main()


