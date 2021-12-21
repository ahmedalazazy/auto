#!/usr/bin/env bash
while IFS= read -r PROJECT; do
gcloud config set project "$PROJECT"

gsutil list > bucets_on_project_"$PROJECT".txt

gsutil -o GSUtil:default_project_id="$PROJECT" du -shc | tr -s " " "," 2> "$PROJECT"_bucets_siza.csv

done <<< $(cat file00.txt )