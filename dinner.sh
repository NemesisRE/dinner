#!/bin/bash

DINNER_DIR="$( cd $( dirname ${0} ) && pwd )"

function dinner() {
	$DINNER_DIR/bin/dinner.sh "$@"

}
