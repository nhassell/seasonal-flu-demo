"""Join two tables.
"""
import argparse

import pandas as pd


if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--left", required=True, help="left table to join")
    parser.add_argument("--right", required=True, help="right table to join")
    parser.add_argument("--how", default="left", choices=["left", "inner", "outer"], help="how to join tables")
    parser.add_argument("--on", default=["strain"], nargs="+", help="columns to join tables on")
    parser.add_argument("--column", default="reference_type", help="columns to fill NA values with")
    parser.add_argument("--column_na", default="Sample", help="NA value fill for column")
    parser.add_argument("--output", required=True, help="joined tables")

    args = parser.parse_args()

    left = pd.read_csv(args.left, sep="\t")
    right = pd.read_csv(args.right, sep="\t")

    joined_table = left.merge(
        right,
        how=args.how,
        on=args.on,
    )
    
    joined_table[args.column] = joined_table[args.column].fillna(args.column_na)

    joined_table.to_csv(
        args.output,
        sep="\t",
        index=False,
        header=True,
        na_rep="N/A",
    )
