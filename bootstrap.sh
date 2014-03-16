#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#
# Copyright 2013, Steven Koeberich (nemesissre@gmail.com)
#
# Title:			Dinner
# Author:			Steven "NemesisRE" Koeberich
# Author URL:		https://nrecom.net
# Contributors:		ToeiRei
# Creation Date:	20131117
# Version:			2.0
# Description:		Builds Roms automatically
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at (http://www.gnu.org/licenses/) for
# more details.


#set -x

TXTDEF="\e[0m"    # Revert to default
BLDRED="\e[1;31m" # Red - error
BLDGRN="\e[1;32m" # Green - success
BLDYLW="\e[1;33m" # Yellow - warning
BLDBLU="\e[1;34m" # Blue - no action/ignored
BLDPUR="\e[1;35m" # Purple - fatal
BLDCYN="\e[1;36m" # Cyan - pending
BLDWHT="\e[1;37m" # White - notice
HALIGN="13"

if [[ ${EUID} -eq 0 ]]; then
	echo "For your own safety, do not run as root user!"
	exit 1
fi

until [[ "${UVY}" =~ [yY] ]]; do
	unset UVY USERVALUE
	printf "${BLDWHT}%${HALIGN}b:\t%b\n${TXTDEF}" " " "Where do want Dinner to be installed? (Default: ${HOME}/.dinner )"
	printf "${BLDWHT}%${HALIGN}b:\t${TXTDEF}" "PATH"
	read DINNER_INSTALL_PATH
	[[ -z ${DINNER_INSTALL_PATH} ]] && DINNER_INSTALL_PATH="${HOME}/.dinner"
	printf "${BLDBLU}%${HALIGN}b:\t${TXTDEF}" "Is REPO_DIR=\"${USERVALUE}\" correct? (y/N): "
	read -n1 UVY
done

### Install dinner ###
if [ $(which git) ]; then
	$(which git) clone https://github.com/NemesisRE/dinner.git ${DINNER_INSTALL_PATH}
else
	echo "Could not find git executable, please install git and try again."
fi

# Source .dinner in .bashrc
grep -xq 'source ${DINNER_INSTALL_PATH}/helper/dinner_completion.sh' ${HOME}/.bashrc || printf '\nsource ${DINNER_INSTALL_PATH}/helper/dinner_completion.sh"' >> ${HOME}/.bashrc
grep -xq 'export PATH=$PATH:${DINNER_INSTALL_PATH}/bin' ${HOME}/.bashrc || printf '\nexport PATH=$PATH:${DINNER_INSTALL_PATH}/bin' >> ${HOME}/.bashrc

echo "Please relog or run \"source ${HOME}/.bashrc\" then you can start dinner by typing \"dinner\""
