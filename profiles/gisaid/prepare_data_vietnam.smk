ruleorder: prepare_sequences > parse

# Assumes that metadata XLS is the XLS metadata file downloaded from GISAID for
# the same samples that appear in the raw sequences FASTA below.
#
# 1. Convert metadata from XLS to CSV for better downstream parsing.
# 2. Select only the metadata fields that we need.
# 3. Rename GISAID fields to Nextstrain standard field names.
# 4. Split the "location" field into four separate geographic fields with standard Nextstrain field names.
# 5. Remove whitespace in strain names to make names consistent with the sequence records as processed below.
# 6. Sort records in descending order by strain name and accession such that the most recent accession for each strain appears first.
# 7. Select the first record for each unique strain name in the metadata, keeping the most recent accession.
rule prepare_metadata:
    input:
        metadata_s="data/{lineage}/metadata.xls",
        metadata_r="data/{lineage}/references.xls",
    output:
        metadata_s="data/{lineage}/metadata_s.tsv",
        metadata_r="data/{lineage}/metadata_r.tsv",
        metadata="data/{lineage}/metadata.tsv",
    params:
        old_fields=",".join(config["metadata_fields"]),
        new_fields=",".join(config["renamed_metadata_fields"]),
    conda: "../../workflow/envs/nextstrain.yaml"
    shell:
        """
        python3 scripts/xls2csv.py --xls {input.metadata_s} --output /dev/stdout \
            | csvtk cut -f {params.old_fields} \
            | csvtk rename -f {params.old_fields} -n {params.new_fields} \
            | csvtk sep -f location --na "N/A" --names region,country,division,location --merge --num-cols 4 --sep " / " \
            | csvtk replace -f strain -p " " -r "" \
            | csvtk sort -k strain,accession:r \
            | csvtk uniq -T -f strain > {output.metadata_s};
        python3 scripts/xls2csv.py --xls {input.metadata_r} --output /dev/stdout \
            | csvtk cut -f {params.old_fields} \
            | csvtk rename -f {params.old_fields} -n {params.new_fields} \
            | csvtk sep -f location --na "N/A" --names region,country,division,location --merge --num-cols 4 --sep " / " \
            | csvtk replace -f strain -p " " -r "" \
            | csvtk sort -k strain,accession:r \
            | csvtk uniq -T -f strain > {output.metadata_r};
        cat {output.metadata_s} <(tail -n +2 {output.metadata_r}) > {output.metadata};
        """

# Assumes that "raw sequences" FASTA is downloaded from GISAID with only the
# "Isolate_name" field selected such that each record looks like:
# ">strain name|accession".
#
# 1. Remove spaces from strain names.
# 2. Add unique id to duplicate strain name and accession pairs.
# 3. Sort sequences in descending order by strain and accession (latest accession comes first).
# 4. Replace "|" character with space, changing record name to strain name only.
# 5. Keep the first sequence for a given strain name, keeping the sequence for the most recent accession.
rule prepare_sequences:
    input:
        sequences_s="data/{lineage}/raw_sequences_{segment}.fasta",
        sequences_r="data/{lineage}/references_{segment}.fasta",
    output:
        sequences_s="data/{lineage}/{segment}_s.fasta",
        sequences_r="data/{lineage}/{segment}_r.fasta",
        sequences="data/{lineage}/{segment}.fasta",
    conda: "../../workflow/envs/nextstrain.yaml"
    shell:
        """
        seqkit replace -p " " -r "" {input.sequences_s} \
            | seqkit rename \
            | seqkit sort -n -r \
            | seqkit replace -p "\|" -r " " \
            | seqkit rmdup > {output.sequences_s};
        seqkit replace -p " " -r "" {input.sequences_r} \
            | seqkit rename \
            | seqkit sort -n -r \
            | seqkit replace -p "\|" -r " " \
            | seqkit rmdup > {output.sequences_r};
        cat {output.sequences_s} {output.sequences_r} > {output.sequences};
        """
