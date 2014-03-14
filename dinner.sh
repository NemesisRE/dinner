#!/bin/bash

source ${HOME}/.dinner/helper/dinner_completion.sh

function dinner () {
	${HOME}/.dinner/bin/dinner.sh "$@"
}
