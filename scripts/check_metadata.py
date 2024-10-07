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



def test_header_row(file, barcode_column_name):
    with open(file, 'r') as f:
        header = f.readline()
        if not header:
            print("Error: file is empty")
            sys.exit(1)

        if not all(header.split('\t')):
            print("Error: header row has empty columns")
            sys.exit(1)

        # Check if barcode column name is in header
        if barcode_column_name:
            if not barcode_column_name in header:
                print(f"Error: {barcode_column_name} column name not found in header")
                sys.exit(1)



def test_unique_values(file):
    columns = []
    categorical_columns = []
    with open(file, 'r') as f:

        # remove newline character from header
        header = f.readline().strip().split('\t')

        rows = f.readlines()

        for i in range(1, len(header)):
            unique_values = set()
            columns.append([])
            nr_rows = 0
            for line in rows:
                cell = line.strip().split('\t')
                nr_rows += 1
                unique_values.add(cell[i])
                # print(cell[i])

        
            if len(unique_values) < 2 :
                print(f"Error: column {header[i]} has no unique values ({len(unique_values)})")
                print("Unique values: ", list(unique_values))
            elif len(unique_values) == nr_rows:
                print("Error: column " + header[i] + " has only unique values")
            else:
                categorical_columns.append(header[i])
                print(f"Column {header[i]} has {len(unique_values)} unique values")

    if not categorical_columns:
        print("Error: no column has more than one unique value")
        sys.exit(1)
    else:
        print("Categorical columns: ", categorical_columns)
    return categorical_columns


def main():
    # Get file from command line

    # cli interface for testing using argparse

    import argparse
    parser = argparse.ArgumentParser(description='Check if metadata file is in tsv format and has valid header row')
    parser.add_argument('file', type=str, help='metadata file to check')
    parser.add_argument('--barcode_column_name', default="barcode-sequence", help='check if file is in tsv format')
    args = parser.parse_args()


    
    file = args.file
    if not os.path.isfile(file):
        print("Error: file not found")
        sys.exit(1)

    test_tsv_format(file)
    test_header_row(file, args.barcode_column_name)
    test_unique_values(file)
    print("File is in tsv format, header row has valid strings, and at least one column has more than one unique value but less than column length")





# if main execute the main function
if __name__ == "__main__":
    main()


