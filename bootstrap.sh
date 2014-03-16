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
#
#
# Paste this into your shell
# curl -sL https://raw.github.com/NemesisRE/dinner/master/bootstrap.sh | /bin/bash


#set -x

TXTDEF="\e[0m"    # Revert to default
BLDRED="\e[1;31m" # Red - error
BLDGRN="\e[1;32m" # Green - success
BLDYLW="\e[1;33m" # Yellow - warning
BLDBLU="\e[1;34m" # Blue - no action/ignored
BLDWHT="\e[1;37m" # White - notice

if [[ ${EUID} -eq 0 ]]; then
	printf "${BLDRED}%b\n${TXTDEF}" "For your own safety, do not run as root user!"
	exit 1
fi

printf "${BLDWHT}%b\n${TXTDEF}" "Where do want Dinner to be installed? (Default: ${HOME}/.dinner )"
until [[ "${UVY}" =~ [yY] ]]; do
	unset UVY DINNER_INSTALL_PATH
	printf "${BLDWHT}%b${TXTDEF}" "PATH: "
	read DINNER_INSTALL_PATH
	[[ -z ${DINNER_INSTALL_PATH} ]] && DINNER_INSTALL_PATH="${HOME}/.dinner"
	if ! [[ ${DINNER_INSTALL_PATH} =~ ^/.* ]]; then
		DINNER_INSTALL_PATH=${HOME}/${DINNER_INSTALL_PATH}
	fi
	if [ -e ${DINNER_INSTALL_PATH} ]; then
		printf "${BLDYLW}%b\n${TXTDEF}" "Path:\"${DINNER_INSTALL_PATH}\" already exists, choose an other."
		continue
	fi
	printf "${BLDBLU}%b${TXTDEF}" "Is this \"${DINNER_INSTALL_PATH}\" correct? (y/N): "
	read -n1 UVY
	echo " "
done

### Install dinner ###
if [ $(which git) ]; then
	$(which git) clone https://github.com/NemesisRE/dinner.git ${DINNER_INSTALL_PATH}
else
	printf "${BLDRED}%b\n${TXTDEF}" "Could not find git executable, please install git and try again."
	exit 1
fi

# Source .dinner in .bashrc
grep -xq "source ${DINNER_INSTALL_PATH}/helper/dinner_completion.sh" ${HOME}/.bashrc || printf "\nsource ${DINNER_INSTALL_PATH}/helper/dinner_completion.sh" >> ${HOME}/.bashrc
grep -xq "export PATH=\$PATH:${DINNER_INSTALL_PATH}/bin" ${HOME}/.bashrc || printf "\nexport PATH=\$PATH:${DINNER_INSTALL_PATH}/bin" >> ${HOME}/.bashrc

printf "${BLDGRN}\n\n%b\n${TXTDEF}" "Please relog or run \"source ${HOME}/.bashrc\"\nThen you can start using Dinner by typing \"dinner\""
