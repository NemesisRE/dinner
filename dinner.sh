#!/bin/bash

source $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/helper/dinner_completion.sh

function dinner() {
	$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/bin/dinner.sh "$@"
}
