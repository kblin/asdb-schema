#!/bin/bash

set -o nounset

echo "Using ${PSQL_HOST:=localhost}:${PSQL_PORT:=5432} with db ${PSQL_DB:=antismash}, schema ${PSQL_SCHEMA:=antismash} as ${PSQL_USER:=postgres}"
PSQL="psql -h $PSQL_HOST -p $PSQL_PORT -U $PSQL_USER"
PSQL_AS="$PSQL $PSQL_DB"

$PSQL -tc "SELECT 1 FROM pg_database WHERE datname = '${PSQL_DB}';" | grep -q 1 || $PSQL -c "CREATE DATABASE $PSQL_DB;"

echo "Clearing out the whole schema"
$PSQL_AS -c "DROP SCHEMA IF EXISTS ${PSQL_SCHEMA} CASCADE;" > /dev/null 2>&1

$PSQL_AS -c "CREATE SCHEMA IF NOT EXISTS ${PSQL_SCHEMA};" > /dev/null 2>&1
# tables not depending on other tables
TABLES="sampling_sites bgc_types substrates taxa profiles "
TABLES="$TABLES as_domain_profiles pfams gene_ontologies resfams"
# tables depending on other tables. Please keep the order intact
TABLES="$TABLES bgc_rules samples isolates genomes dna_sequences"
TABLES="$TABLES regions candidates protoclusters"
TABLES="$TABLES functional_classes smcogs cdss genes"
TABLES="$TABLES ripps t2pks monomers modules"
TABLES="$TABLES as_domains clusterblast_algorithms clusterblast_hits tta_codons"
TABLES="$TABLES pfam_domains pfam_go_entries filenames resfam_domains"
# tables that create many-to-many relations
TABLES="$TABLES rel_candidates_protoclusters rel_candidates_types rel_candidates_modules"
TABLES="$TABLES rel_cds_candidates rel_cds_protoclusters"
TABLES="$TABLES rel_regions_types"
TABLES="$TABLES rel_as_domains_substrates smcog_hits profile_hits rel_modules_monomers"
# views that depend on all this stuff
TABLES="$TABLES view_sequence_gc_content view_sequence_lengths"
# precalculated data, load this last
TABLES="$TABLES preload_taxa"

for t in $TABLES; do
    if [ -f "${t}.sql" ]; then
        echo "Processing $t"
    else
        echo "no such file: ${t}.sql"
        exit 1
    fi
    $PSQL_AS 2>&1 < "${t}.sql" | tee tmp | grep ERROR
    if [ "$?" -eq "0" ]; then
        cat tmp
        rm tmp
        exit 1
    fi
    rm tmp
done
