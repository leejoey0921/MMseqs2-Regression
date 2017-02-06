#!/bin/bash -e
BENCHDIR=${1}
MMSEQS=${2}
VERSION=${3}
RESULTDIR=${4}
PROFILE=${5:-0}

BENCHDB="small-benchmark-db"

QUERY="$BENCHDIR/${BENCHDB}/query.fasta"
QUERYDB="$BENCHDIR/${BENCHDB}/query"
TARGETDB="$BENCHDIR/${BENCHDB}/db2"
DBANNOTATION="$BENCHDIR/${BENCHDB}/targetannotation.fasta"

RESULTS="${RESULTDIR}/mmseqs-regression-${VERSION}"

TIMERS=()
function lap() { TIMERS+=($(date +%s.%N)); }
SEARCH_PARM="--min-ungapped-score 15 -e 10000.0 -s 4 --max-seqs 4000 --split 1"
if [ $PROFILE -ne 0 ]; then
    SEARCH_PARM="--min-ungapped-score 0 -e 10000.0 -s 4 --max-seqs 4000 --e-profile 0.001 --num-iterations 2 --split 1 "
fi

rm -rf "$RESULTS"
mkdir -p "$RESULTS/tmp"
lap
${MMSEQS} createindex "$TARGETDB" --split 1 1>&2 || exit 125
lap
${MMSEQS} search "$QUERYDB" "$TARGETDB" "$RESULTS/results_aln" "$RESULTS/tmp" ${SEARCH_PARM} 1>&2 || exit 125 
lap
${MMSEQS} convertalis "$QUERYDB" "$TARGETDB" "$RESULTS/results_aln" "$RESULTS/results_aln.m8" ${VERBOSE} 1>&2  || exit 125
lap
rm -rf ${TARGETDB}.sk*

if [ $PROFILE -ne 0 ]; then
    sort -k1,1 -k11,11g "$RESULTS/results_aln.m8" > "$RESULTS/results_aln_sorted.m8"
    mv "$RESULTS/results_aln_sorted.m8" "$RESULTS/results_aln.m8"
fi
EVALPREFIX="$BENCHDIR/${BENCHDB}/results-${VERSION}/evaluation"
$BENCHDIR/${BENCHDB}/evaluate_results "$QUERY" "$DBANNOTATION" "$RESULTS/results_aln.m8" "${EVALPREFIX}_roc5.dat" 4000 1 > "${EVALPREFIX}.log"

AUC=$(grep "^ROC5 AUC:" "${EVALPREFIX}.log" | cut -d" " -f3)
echo -e "${VERSION}\t${AUC}\t$(printf '%s\t' "${TIMERS[@]}")"