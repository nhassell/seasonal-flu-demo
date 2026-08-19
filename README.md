# Seasonal Flu GISAID Workflow

This repository contains a [Nextstrain](https://nextstrain.org) workflow for building
annotated phylogenetic trees of seasonal influenza from GISAID data.

Three lineages are supported: **A/H1N1pdm**, **A/H3N2**, and **B/Vic**.
Each can be run independently for the **HA** or **NA** segment using the
pre-configured build files in `profiles/gisaid/`.

## Prerequisites

Install [Nextstrain's software tools](https://docs.nextstrain.org/en/latest/install.html)
before running any builds.

## Available builds

| Config file | Lineage | Segment |
|---|---|---|
| `profiles/gisaid/custom_gisaid_h1n1pdm_ha.yaml` | A/H1N1pdm | HA |
| `profiles/gisaid/custom_gisaid_h1n1pdm_na.yaml` | A/H1N1pdm | NA |
| `profiles/gisaid/custom_gisaid_h3n2_ha.yaml` | A/H3N2 | HA |
| `profiles/gisaid/custom_gisaid_h3n2_na.yaml` | A/H3N2 | NA |
| `profiles/gisaid/custom_gisaid_vic_ha.yaml` | B/Vic | HA |
| `profiles/gisaid/custom_gisaid_vic_na.yaml` | B/Vic | NA |

## Data download from GISAID

Each build requires six files downloaded from [GISAID EpiFlu](https://www.epicov.org/epi3/).
Files must be placed in `data/{segment}/{lineage}/` — for example, H1N1pdm HA data goes in
`data/ha/h1n1pdm/`. This directory layout allows HA and NA builds to run without
overwriting each other's files.

```
data/
  ha/
    h1n1pdm/
      metadata.xls
      genetic.xls
      reagent.xls
      raw_sequences_ha.fasta
      genetic_ha.fasta
      reagent_ha.fasta
  na/
    h1n1pdm/
      metadata.xls
      ...
```

### Downloading sample sequences and metadata

1. Go to **EpiFlu → Search** on GISAID.
2. Filter by lineage (e.g. A/H1N1pdm), host = Human, and your desired date range.
3. Under **Required Segments**, select your segment (HA or NA).
4. Click **Search**, then select all results.
5. Click **Download → Isolates as XLS (virus metadata only)**.
   Save as `data/{segment}/{lineage}/metadata.xls`.
6. Click **Download → Sequences (DNA) as FASTA**.
   - Under **DNA**, select only your segment.
   - Under **FASTA Header**, enter `Virus name`.
   Save as `data/{segment}/{lineage}/raw_sequences_{segment}.fasta`.

### Downloading genetic (reference) sequences and metadata

1. Navigate to [CDC Seasonal Flu Sequence References](https://cdcgov.github.io/influenza-resources/resources/datasets/seasonal-flu-sequence-references/), go to the "Contemporary" genetic references section.
2. Click on the correct lineage and segment link to go to the GISAID EPI_SET interface.
3. Enter your login information to continue to the GISAID EpiFlu interface with the EPI_SET loaded.
4. Download the metadata XLS and save as `data/{segment}/{lineage}/genetic.xls`.
5. Download the FASTA with header `Virus name` and save as
   `data/{segment}/{lineage}/genetic_{segment}.fasta`.

### Downloading reagent sequences and metadata

1. In GISAID EpiFlu, go to **Downloads → Reagent Sequences**.
2. Select your lineage and segment.
3. Download the metadata XLS and save as `data/{segment}/{lineage}/reagent.xls`.
4. Download the FASTA with header `Virus name_Passage details/history` and save as
   `data/{segment}/{lineage}/reagent_{segment}.fasta`.

## Running a build

Run a build by passing its config file to `nextstrain build`:

```bash
# H1N1pdm HA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_h1n1pdm_ha.yaml

# H1N1pdm NA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_h1n1pdm_na.yaml

# H3N2 HA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_h3n2_ha.yaml

# H3N2 NA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_h3n2_na.yaml

# B/Vic HA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_vic_ha.yaml

# B/Vic NA
nextstrain build . --configfile profiles/gisaid/custom_gisaid_vic_na.yaml
```

When the build finishes, view the tree:

```bash
nextstrain view auspice/
```

Output JSONs are written to `auspice/` with names matching the build name and segment,
e.g. `auspice/custom_h1n1pdm_na.json`.

## Customising a build

**Change the defaults within the auspice display**

- Open the auspice config file for your build, e.g.
  `config/h1n1pdm/ha/auspice_config_custom.json`.
- Edit the `title`, `maintainers`, `build_url`, etc. sections to reflect your build.

**Change the time window** — set `min_date` to any ISO date:

```yaml
min_date: "2024-01-01"
```

**Change subsampling** — by default, the build will include all samples from the build file `subsamples` definition.

The default is:

```yaml
subsamples:
  global:
    filters: ""
```

To create a custom subsampling scheme, you can modify the `filters` field. For example, create a custom regional subsampling scheme that includes all reference and reagent strains, but limits the number of sequences and collection timeliness you could do the following:

```yaml
subsamples:
  global:
    filters: "--min-date {min_date} --group-by country year month --subsample-max-sequences 150 --include {include} --exclude-where 'region=oceania'"
    oceania:
      filters: "--min-date {min_date} --group-by country year month --subsample-max-sequences 100 --include {include} --exclude-where 'region!=oceania'"
    australia:
      filters: "--min-date {min_date} --group-by division year month --subsample-max-sequences 200 --include {include} --exclude-where 'country!=australia'"
```

If you downloaded a metadata and sequence file that contains all of your country samples you want to include but also
wanted a regional+global subsampling, you could edit the subsampling scheme as follows:

```yaml
subsamples:
  global:
    filters: "--min-date {min_date} --group-by country year month --subsample-max-sequences 150 --include {include} --exclude-where 'region=oceania'"
    oceania:
      filters: "--min-date {min_date} --group-by country year month --subsample-max-sequences 100 --include {include} --exclude-where 'region!=oceania'"
    australia:
      filters: "--min-date {min_date} --group-by division year month --subsample-max-sequences 10000 --include {include} --exclude-where 'country!=australia'"
```

By upping the `subsample-max-sequences` for the `australia` subsampling scheme, you can include all of your Australian samples while still subsampling the rest of the world/region.

## Notes

- Each build config sets `data_per_segment: true`, which routes input data through
  `data/{segment}/{lineage}/` so HA and NA builds can coexist without conflicts.
- Reference and reagent strains are force-included in the tree regardless of `min_date`
  via the `include` field, which points to `config/{lineage}/{segment}/reference_strains.txt`.
  This file is regenerated on each run from your GISAID reagent/genetic downloads.
- HA clade assignments are only computed for HA builds. NA builds use NA-specific
  subclades defined in `config/{lineage}/na/subclades.tsv`.
- Required config files per segment (reference, annotation, exclude-sites) are located
  in `config/{lineage}/{segment}/`.

[Nextstrain]: https://nextstrain.org
[augur]: https://github.com/nextstrain/augur
[auspice]: https://github.com/nextstrain/auspice

