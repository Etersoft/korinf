#!/bin/sh
PROJECT=korinf
git push --all $1 git.eter:packages/$PROJECT.git
git push --all $1 git.alt:packages/$PROJECT.git
git push --tags $1 git.eter:packages/$PROJECT.git
git push --tags $1 git.alt:packages/$PROJECT.git
