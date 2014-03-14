#!/bin/bash

#source $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/helper/dinner_completion.sh

function dinner () {
	source $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/helper/dinner_completion.sh
	$(cd "$(dirname "${0}")" && pwd -P)/bin/dinner.sh "$@"
}
