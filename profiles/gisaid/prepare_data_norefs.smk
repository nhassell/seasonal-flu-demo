ruleorder: prepare_sequences > parse
ruleorder: prepare_metadata > annotate_metadata_with_reference_strains

rule pull_clade_files:
    output:
        h3n2_ha_clades="config/h3n2/ha/clades.tsv",
        h1n1pdm_ha_clades="config/h1n1pdm/ha/clades.tsv",
        vic_ha_clades="config/vic/ha/clades.tsv",
        h3n2_ha_subclades="config/h3n2/ha/subclades.tsv",
        h3n2_na_subclades="config/h3n2/na/subclades.tsv",
        h1n1pdm_ha_subclades="config/h1n1pdm/ha/subclades.tsv",
        h1n1pdm_na_subclades="config/h1n1pdm/na/subclades.tsv",
        vic_ha_subclades="config/vic/ha/subclades.tsv",
        vic_na_subclades="config/vic/na/subclades.tsv",
        out_text = "config/subclades.done"
    conda: "../../workflow/envs/nextstrain.yaml"
    shell:
        """
        curl -o {output.h3n2_ha_clades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H3N2_HA/main/.auto-generated/clades.tsv";
        curl -o {output.h1n1pdm_ha_clades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H1N1pdm_HA/main/.auto-generated/clades.tsv";
        curl -o {output.vic_ha_clades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_B-Vic_HA/main/.auto-generated/clades.tsv";
        curl -o {output.h3n2_ha_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H3N2_HA/main/.auto-generated/subclades.tsv";
        curl -o {output.h3n2_na_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H3N2_NA/main/.auto-generated/subclades.tsv";
        curl -o {output.h1n1pdm_ha_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H1N1pdm_HA/main/.auto-generated/subclades.tsv";
        curl -o {output.h1n1pdm_na_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_A-H1N1pdm_NA/main/.auto-generated/subclades.tsv";
        curl -o {output.vic_ha_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_B-Vic_HA/main/.auto-generated/subclades.tsv";
        curl -o {output.vic_na_subclades} "https://raw.githubusercontent.com/influenza-clade-nomenclature/seasonal_B-Vic_NA/main/.auto-generated/subclades.tsv";
        touch {output.out_text};
        """

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
        rules.pull_clade_files.output.out_text,
        metadata_s="data/{lineage}/metadata.xls"
    output:
        metadata_s="data/{lineage}/metadata_s.tsv",
        metadata="data/{lineage}/metadata.tsv"
    params:
        old_fields=",".join(config["metadata_fields"]),
        new_fields=",".join(config["renamed_metadata_fields"])
    conda: "../../workflow/envs/nextstrain.yaml"
    shell:
        """
        python3 scripts/xls2csv.py --xls {input.metadata_s} --output /dev/stdout \
            | csvtk cut -f {params.old_fields} \
            | csvtk rename -f {params.old_fields} -n {params.new_fields} \
            | csvtk sep -f full_location --na "N/A" --names region,country,division,location --merge --num-cols 4 --sep " / " \
            | csvtk replace -f strain -p "[^A-z0-9/\-_]" -r "" \
            | csvtk sort -k strain,accession:r \
            | csvtk uniq -T -f strain \
            | csvtk mutate2 -n sample_type -e '"sample"' -t > {output.metadata_s};
        csvtk sort -t -k strain,accession:r {output.metadata_s} \
            | csvtk uniq -t -T -f strain > {output.metadata};
        """

# Assumes that "raw sequences" FASTA is downloaded from GISAID with only the
# "Isolate_name" field selected such that each record looks like:
# ">strain name|accession".
#
# 1. Remove spaces from strain names.
# 2. Add unique id to duplicate strain name and accession pairs.
# 3. Sort sequences in descending order by strain and accession (latest accession comes first).
# 4. Replace "|" character with space, changing record name to strain name only.
# 5. Replace "U" characters in sequence with "T".
# 6. Keep the first sequence for a given strain name, keeping the sequence for the most recent accession.
rule prepare_sequences:
    input:
        sequences_s="data/{lineage}/raw_sequences_{segment}.fasta",
        metadata_s=rules.prepare_metadata.output.metadata_s
    output:
        sequences_s="data/{lineage}/{segment}_s.fasta",
        sequences="data/{lineage}/{segment}.fasta"
    conda: "../../workflow/envs/nextstrain.yaml"
    shell:
        """
        seqkit replace -p " " -r "" {input.sequences_s} \
            | seqkit rename \
            | seqkit sort -n \
            | seqkit replace -p "[^A-z0-9/\-_\|]" -r "" \
            | seqkit replace -p "\|" -r " " \
            | seqkit replace -s -p "[Uu]" -r "T" \
            | seqkit rmdup > {output.sequences_s};
        seqkit rmdup {output.sequences_s} \
            | seqkit sort -n > {output.sequences};
        """
