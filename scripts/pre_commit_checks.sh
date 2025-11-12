#!/bin/bash

ERROR=0

# Simple script which executes some of the scripts here for a pre-commit check to verify that everything is alright.
# Must be executed from the root of the repo
echo
echo "----------------------------"
echo "Executing dependency checker"
echo "----------------------------"
scripts/dependency_checker.py
if [ $? -ne 0 ]; then
	echo "❌ Dependency checker failed"
	ERROR=1
fi

echo
echo "--------------------"
echo "Executing buf linter"
echo "--------------------"
buf lint
if [ $? -ne 0 ]; then
	echo "❌ Buf linter failed"
	ERROR=1
fi

echo
echo "--------------------------"
echo "Executing buf format check"
echo "--------------------------"
buf format --exit-code > /dev/null
if [ $? -ne 0 ]; then
	echo "❌ Buf format check failed (just run 'buf format -w' to fix it)"
	ERROR=1
fi

echo
echo "-------------------------------------"
echo "Executing proto diagram link verifier"
echo "-------------------------------------"
scripts/verify_diagram_links.sh
if [ $? -ne 0 ]; then
	echo "❌ Proto diagram link verifier failed"
	ERROR=1
fi

echo
echo "----------------------"
echo "Executing FQPN checker"
echo "----------------------"
scripts/fqpn_check.sh
if [ $? -ne 0 ]; then
	echo "❌ FQPN checker failed"
	ERROR=1
fi

echo
echo "----------------------------"
echo "Executing buf breaking check"
echo "----------------------------"
scripts/buf-breaking.sh
if [ $? -ne 0 ]; then
	echo "❌ Buf breaking check failed"
	ERROR=1
fi

if [ $ERROR -ne 0 ]; then
	echo
	echo "---------------------------"
	echo "❌ Pre-commit checks failed"
	echo "---------------------------"
	exit 1
else
	echo
	echo "---------------------------"
	echo "✅ Pre-commit checks passed"
	echo "---------------------------"
	exit 0
fi